---
title: LinkOff - Making LinkedIn Slightly Less Dreadful
description: A deep dive into the engineering of a silly little browser extension that I made as a form of trauma response after spending weeks writing and testing LinkedIn automation code at work.
categories: [Projects]
tags: [browser-extension, javascript, linkedin, web-scraping, content-filtering]
---

> "The only teaching that a professor can give, in my opinion, is that of thinking in front of his students." - Henri Lebesgue

Back during my time at [Lebesgue](https://lebesgue.io) (a boutique marketing insights and analytics company), I was doing a lot of interesting *cross-functional* work, as it was called back then. We had our internal sales pipeline, and it had quite a bit of cold outreach. However, cold-mailing is a pain - from spam filters to bad email lists, it's generally frowned upon. The newer kid on the block, LinkedIn, seemed like a potentially more interesting option. Comparing to email's 5%, LinkedIn often had response rates of 15-20%. 

On top of that, LinkedIn was way more compatible with the new, more personal, founder-focused marketing approach. Instead of presenting as a firm corporate company front, you lead and present the CEO/CTO first and foremost, and make sales based on that.

Because of that, I found myself spending hours every day working on LinkedIn automations. Hours and hours of writing scrapers, dealing with anti-bot measures, handling rate limits, and debugging why the "Connect" button selector changed and broke everything. 

But that also meant I spent hours on LinkedIn... Watching the **Feed**. Ugh. So I built LinkOff. Let this be a tech dive into it.

## What is LinkOff?

[LinkOff](https://github.com/njelich/LinkOff) is a browser extension that transforms LinkedIn from a chaotic social media feed into a focused professional tool. It can hide entire categories of content (polls, videos, promoted posts), filter by keywords, block posts from companies or people, and even mass-delete messages.

## Architecture Overview

LinkOff uses a classic content script architecture that's common in browser extensions:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Popup UI      │◄──►│ Service Worker  │◄──►│ Content Script  │
│  (popup.html)   │    │(service_worker) │    │  (injected JS)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │ Chrome Storage  │
                       │    (local)      │
                       └─────────────────┘
```

### Key Components

1. **Popup UI** (popup/popup.html) - The extension's settings interface
2. **Service Worker** (service_worker.js) - Background script that manages storage defaults
3. **Content Script** (content/content.js) - Injected into LinkedIn pages to modify content
4. **Feature Modules** (features/) - Modular filtering logic for different LinkedIn sections

## The Content Injection Strategy

The most interesting architectural choice is how LinkOff injects its code. Instead of putting everything in the content script directly, it dynamically imports ES6 modules:

```javascript
// src/content/content.js
'use strict'

const src = chrome.runtime.getURL('src/index.js')

// We dynamically import files to be able to use ES6 modules
// Remember to add imported files to web_accessible_resources
import(src)
```

This approach has several benefits:
- **ES6 modules** work properly (content scripts have limited module support)
- **Code splitting** becomes possible
- **Dynamic loading** allows for conditional feature loading
- **Better debugging** with proper source maps

The trade-off is that all imported files must be declared in `web_accessible_resources` in the manifest.

## The Filtering Engine

### DOM Element Selection Strategy

LinkedIn's DOM structure is notoriously unstable - class names change frequently and the site is heavily React-based. LinkOff solves this with a multi-layered selection strategy:

```javascript
// src/constants.js
export const FEED_SELECTORS = [
  '[data-id*="urn:li:activity"]',  // LinkedIn's internal activity URNs
  '[data-id*="urn:li:aggregate"]', // Aggregated content URNs
]

export const JOB_SELECTORS = [
  '[data-job-id]',
  '[data-occludable-job-id]',
  '.discovery-templates-vertical-list__list-item',
]
```

The key insight is using **data attributes** rather than CSS classes. LinkedIn's `data-id` attributes containing URNs (Uniform Resource Names) are much more stable than their styling classes.

### Asynchronous Element Waiting

Since LinkedIn loads content dynamically, LinkOff implements sophisticated waiting logic:

```javascript
// src/utils.js
export const waitForClassName = async (className) => {
  while (checkElementAndPlaceholderByClassName(className)) {
    await new Promise((resolve) => {
      requestAnimationFrame(resolve)
    })
  }
  return document.getElementsByClassName(className)
}

const checkElementAndPlaceholderByClassName = (className) => {
  const found = document.getElementsByClassName(className)
  if (found.length > 0) {
    return Array.from(found).some((element) =>
      element.innerHTML.includes('skeleton') // LinkedIn's loading placeholder
    )
  }
  return true
}
```

This pattern waits for:
1. **Elements to exist** in the DOM
2. **LinkedIn's skeleton loaders** to be replaced with real content
3. **React hydration** to complete

Using `requestAnimationFrame` ensures the waiting loop doesn't block the UI thread.

## The Three-Mode Filtering System

LinkOff implements three different ways to handle unwanted content:

```javascript
// src/content/content.css
.hide[class] {
  display: none !important;
}

.dim:not(:hover) > * {
  opacity: 0.05 !important;
  filter: alpha(opacity=5) !important;
}

.dim.showIcon:not(:hover)::after {
  content: '';
  background-image: var(--hide-icon);
  background-size: cover;
  width: 30px;
  height: 30px;
}
```

1. **Hide mode**: Complete removal (`display: none`)
2. **Dim mode**: Fade to 5% opacity with click-to-reveal (so funky right?)
3. **Icon overlay**: Visual indicator showing content was filtered

The "gentle mode" (dim) is particularly clever - it lets users verify the filtering is working correctly without permanently losing content.

## Real-Time Keyword Filtering

The feed filtering system is the most complex part of LinkOff:

```javascript
// src/features/feed.js
const blockByFeedKeywords = (keywords, mode, disablePostCount) => {
  if (keywords.length)
    feedKeywordInterval = setInterval(() => {
      // Select posts which are not already hidden
      posts = document.querySelectorAll(
        getCustomSelectors(FEED_SELECTORS, 'pristine')
      )

      // Filter only if there are enough posts to load more
      if (posts.length > 5 || mode == 'dim') {
        posts.forEach((post) => {
          const containsKeyword = keywords.some((keyword) => {
            const splitted = keyword.split('::')
            
            if (splitted.length > 1) {
              return post.innerText.indexOf(splitted[1]) !== -1  // text content
            }
            return post.innerHTML.indexOf(splitted[0]) !== -1    // HTML content
          })

          if (containsKeyword) {
            hidePost(post, mode)
          }
        })
      }
    }, 350)
}
```

Key engineering decisions:

1. **Polling every 350ms** - Balance between responsiveness and performance
2. **`posts.length > 5` check** - LinkedIn's infinite scroll needs a minimum number of posts to trigger loading more
3. **Text vs HTML filtering** - `text::` prefix filters visible text, otherwise filters HTML
4. **State tracking** - Posts are marked with `data-hidden` attributes to avoid reprocessing

## Post Age Based Filtering

Who loves standardized datte time formats? I don't. LinkedIn uses a mix of relative times ("2h", "3d") and absolute dates ("Sep 15", "Jan 5, 2020"). LinkOff implements a cascading keyword system to handle this:

```javascript
// src/features/feed.js
const handleAgeFiltering = (keywords, age) => {
  const ageKeywords = {
    hour: 'h •',
    day: 'd •', 
    week: 'w •',
    month: 'mo •',
    year: 'y •',
  }

  const hideByHour = (shouldLoop = true) => {
    if (shouldLoop) {
      for (let x = 2; x <= 24; x++) {
        keywords.push(`text::${x}${ageKeywords.hour}`)  // "2h •", "3h •", etc.
      }
    }
    hideByDay(false)  // Cascade to hide older content too
  }
}
```

This cascading approach means "hide posts older than 1 day" will also hide posts older than 1 week, 1 month.

## Storage and State Management (Settings)

LinkOff uses Chrome's local storage API with a sophisticated default system:

```javascript
// src/service_worker.js
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    chrome.storage.local.set({
      initialized: 'v0.5',
      'gentle-mode': true,
      'hide-promoted': true,
      'hide-suggested': true,
      'sort-by-recent': true,
      // ... dozens more defaults
    })
  }
})
```

The main content script listens for storage changes and reacts in real-time:

```javascript
// src/index.js
chrome.storage.onChanged.addListener(() => {
  getStorageAndDoIt()
})

const doIt = async (response) => {
  if (JSON.stringify(oldResponse) === JSON.stringify(response)) return
  
  const getRes = (field, bool) => {
    const changed = response[field] !== oldResponse[field] ||
                   response['gentle-mode'] !== oldResponse['gentle-mode'] ||
                   response['main-toggle'] !== oldResponse['main-toggle']
    return changed && response[field] == bool
  }
  
  // Only update features that actually changed
  doFeed(getRes, enabled, mode, response)
  doJobs(getRes, enabled, mode, response)
  doMisc(getRes, enabled, mode)
}
```

This change detection system ensures only modified features are updated, preventing unnecessary DOM manipulation.

## The Popup UI: Tagify Integration

The keyword input system uses [Tagify](https://github.com/yaireo/tagify), a sophisticated tag input library:

```javascript
// src/popup/popup.js
const feedKeywords = document.querySelector('input[id=hide-by-keywords]')
const feedTagify = new Tagify(feedKeywords, {
  whitelist: [
    'Be the first to comment',
    'Jobs recommended for you',
    'New post in',
  ],
  dropdown: {
    position: 'input',
    enabled: 0,
    placeAbove: true,
  },
  originalInputValueFormat: (valuesArr) =>
    valuesArr.map((item) => item.value).join(', '),
})
```

Tagify provides:
- **Autocomplete** with common filtering keywords
- **Tag validation** and formatting
- **Comma-separated value** storage for the backend
- **Professional UI** that matches the extension's design

## Cross-Platform Compatibility

Supporting both Chrome and Firefox required handling browser differences:

```css
/* src/content/content.css */
@supports (-webkit-user-select: none) {
  :root {
    --hide-icon: url('chrome-extension://__MSG_@@extension_id__/src/icons/forbidden.svg');
  }
}

@supports (-moz-user-select: none) {
  :root {
    --hide-icon: url('moz-extension://__MSG_@@extension_id__/src/icons/forbidden.svg');
  }
}
```

The `@supports` CSS feature detection automatically selects the correct extension protocol (`chrome-extension://` vs `moz-extension://`).

## Dark Mode Implementation (happily deprecated since 2023)

LinkOff includes a custom dark mode that pre-dates LinkedIn's official dark mode:

```javascript
// src/features/general.js  
const enableDarkMode = () => {
  const style = document.createElement('style')
  style.innerHTML = colors
    .replace(/100%|0%/g, (m) => m == '100%' ? '0%' : '100%')
    .replace(/#000|#fff/g, (m) => m == '#fff' ? '#000' : '#fff')
    .replace(/#([fe])(.)([fe])(.)([fe])(.)/g, `#1$21$41$6`)
    .replace(/\d+(?=,)/g, (m) => shift255(m))
  
  document.body.appendChild(style)
}
```

This is a **CSS filter inversion approach** - it programmatically inverts colors in LinkedIn's existing stylesheets rather than rewriting them. The regex patterns handle:
- Percentage values (100% ↔ 0%)
- Hex colors (#000 ↔ #fff)
- Bright hex colors (shifts RGB values)
- RGB numeric values (adds 220-255 then modulo 256)

This way it s a bit more dynamic.

## Message Deletion Feature

One of LinkOff's most popular features is bulk message deletion:

```javascript
// src/features/message.js
const selectMessagesForDeletion = async () => {
  const container = document.querySelector('.msg-conversations-container__conversations-list')
  
  await loadAllMessages()  // Scroll to load all conversations
  
  const labels = container.getElementsByTagName('label')
  for (let i = 0; i < labels.length; i++) {
    if (labels[i]) {
      labels[i].click()  // Select each conversation checkbox
    }
  }
  
  alert('Click the trash can icon at the top to delete all messages.')
}

async function loadAllMessages() {
  return await new Promise((resolve) => {
    const interval = setInterval(() => {
      const { scrollHeight } = container
      if (scrollHeight > 20000) {  // Reasonable limit
        clearInterval(interval)
        resolve()
      }
      container.scrollTop = scrollHeight  // Scroll to bottom
    }, 1000)
  })
}
```

This feature:
1. **Auto-scrolls** to load all message conversations
2. **Programmatically clicks** all selection checkboxes
3. **Stops at 20k pixels** to prevent infinite scrolling
4. **Prompts the user** to click the delete button (avoiding destructive automation)

It is also sort of cool, because it was one of the things that were a modification of the LinkedIn UI.

## Build System and Tooling

LinkOff keeps its build system minimal:

```json
// package.json
{
  "scripts": {
    "css-build": "sass src/popup/popup.scss src/popup/popup.css",
    "css-watch": "sass --watch src/popup/popup.scss src/popup/popup.css"
  },
  "dependencies": {
    "@creativebulma/bulma-divider": "^1.1.0",
    "@creativebulma/bulma-tooltip": "^3.0.2", 
    "@yaireo/tagify": "^4.17.9",
    "bulma": "^0.9.4",
    "bulma-switch": "^2.0.0"
  }
}
```

The choice to use **Sass/SCSS** instead of a full build system like Webpack keeps things simple while providing:
- **CSS preprocessing** with variables and mixins
- **Bulma CSS framework** for consistent styling
- **Component libraries** for switches and tooltips
- **Zero JavaScript build step** - just copy files to the extension directory

## Performance Considerations

Several engineering decisions optimize for performance:

### Minimal DOM Queries
```javascript
// Cache selectors to avoid repeated queries
let posts = document.querySelectorAll(getCustomSelectors(FEED_SELECTORS, 'pristine'))
```

### Efficient CSS Selectors
```javascript
// Use attribute selectors instead of class crawling
'[data-id*="urn:li:activity"]'  // Fast
'.feed-post .content .wrapper'   // Slower
```

### Batched Updates
```javascript
// Update all matching elements in one pass
posts.forEach((post) => {
  post.classList.add(mode, 'showIcon')
})
```

### Polling Frequency Balance
```javascript
// 350ms polling - balance between responsiveness and CPU usage
setInterval(() => { /* filter logic */ }, 350)
```

## Security and Permissions

LinkOff requests minimal permissions:

```json
// manifest.json
{
  "permissions": [
    "storage",
    "activeTab"
  ],
  "host_permissions": [
    "https://www.linkedin.com/*"
  ]
}
```

- **`storage`** - For saving user preferences
- **`activeTab`** - Only access the currently active tab when extension is used
- **LinkedIn-only host permissions** - Can't access other websites

This is much more restrictive than many extensions that request `<all_urls>` or persistent background access.

## Testing Strategy

While LinkOff doesn't have formal unit tests, it implements several testing patterns:

### Console Logging
```javascript
console.log(`LinkOff: Found ${posts.length} unblocked posts`)
console.log(`LinkOff: Blocked post ${post.getAttribute('data-id')} for keyword ${keyword}`)
```

### Graceful Error Handling
```javascript
if (!container) {
  alert('No messages. Are you on the messaging page?')
  return
}
```

### User Feedback
```javascript
if (!postCountPrompted && !disablePostCount) {
  alert('Scroll down to start blocking posts (LinkedIn needs at least 10 loaded)')
}
```

These patterns make debugging easier and provide user feedback when things go wrong.

## Lessons Learned

### DOM Stability
**Problem**: LinkedIn's class names change frequently  
**Solution**: Use data attributes and URN patterns instead

### React Compatibility  
**Problem**: React can re-render and remove custom classes  
**Solution**: Use polling and re-apply modifications continuously

### Performance vs Accuracy
**Problem**: Faster polling catches content sooner but uses more CPU  
**Solution**: 350ms polling with batch processing

### User Experience
**Problem**: Users need to understand what's being filtered  
**Solution**: "Gentle mode" with visual indicators and click-to-reveal

## Contributing to LinkOff

The project is currently [looking for a new maintainer](https://github.com/njelich/LinkOff/issues/54). The codebase is well-organized and documented, making it a great starting point for anyone interested in browser extension development.

Key areas for contribution:
- **Mobile support** (Kiwi Browser, Firefox Mobile)
- **Performance optimization** 
- **New filtering features**
- **UI/UX improvements**
- **Cross-browser compatibility**

---

The complete source code is available on [GitHub](https://github.com/njelich/LinkOff) under an MIT license.
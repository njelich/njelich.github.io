---
# the default layout is 'page'
icon: fas fa-calendar
order: 6
---

{% assign current_date = "now" | date: "%s" %}
{% assign upcoming_events = site.data.sessions.events | where_exp: "event", "event.eventEndDate" %}
{% assign past_events = site.data.sessions.events | where_exp: "event", "event.eventEndDate" %}

## **Upcoming Events**
{% assign sorted_upcoming = upcoming_events | sort: 'eventStartDate' %}
{% for event in sorted_upcoming %}
{% assign event_timestamp = event.eventStartDate | date: "%s" %}
{% if event_timestamp >= current_date %}
{% assign event_date = event.eventStartDate | date: "%B %d, %Y" %}

##### {{ event.name }}
**📍 Location:** {{ event.location | default: "Virtual Event" }}  
**📅 Date:** {{ event_date }}  
{% if event.website %}**🔗 Website:** [{{ event.website | remove: 'https://' | remove: 'http://'}}]({{ event.website }}){% endif %}

---
{% endif %}
{% endfor %}


## **Past Events**
{% assign sorted_past = past_events | sort: 'eventStartDate' | reverse %}
{% for event in sorted_past %}
{% assign event_timestamp = event.eventStartDate | date: "%s" %}
{% if event_timestamp < current_date %}
{% assign event_date = event.eventStartDate | date: "%B %d, %Y" %}

##### {{ event.name }}
**📍 Location:** {{ event.location | default: "Virtual Event" }}  
**📅 Date:** {{ event_date }}  
{% if event.website %}**🔗 Website:** [{{ event.website | remove: 'https://' | remove: 'http://' }}]({{ event.website }})  {% endif %}
{% if event.description %}**📝 Description:** {{ event.description }}{% endif %}
{% if event.links %}
<div style="display: flex; gap: 10px; flex-wrap: wrap; margin: 10px 0;">
{% for link in event.links %}
{% if link contains 'youtube.com' or link contains 'youtu.be' %}
  {% assign video_id = link | split: 'v=' | last | split: '&' | first %}
  {% if video_id == link %}
    {% assign video_id = link | split: '/' | last | split: '?' | first %}
  {% endif %}
  <iframe width="240" height="135" src="https://www.youtube.com/embed/{{ video_id }}" frameborder="0" allowfullscreen></iframe>
{% else %}
  <iframe src="{{ link }}"  width="240"  height="132"  frameborder="0"  scrolling="auto" allowfullscreen="true" ></iframe>
{% endif %}
{% endfor %}
</div>
{% endif %}

---
{% endif %}
{% endfor %}
 
## **Current Talks**

### Killing With Keyboards: How Your Digital Footprint Can Be Weaponized

Sashko is a security researcher at REDACTED, and he is about to become a key chess piece in the game of digital warfare. Join me as I explore the story of how even benign online activities can be weaponized against individuals and organizations.

This talk will equip you with the mindset to recognize and mitigate digital threats before they strike. Learn how adversaries think, how data leaks occur, and how to fortify your online presence against those who weaponize information.

### Breaking Narratives: How Code Review Beats Marketing Decks

Everything today seems to be hype and empty promises, so where does one find the real edge? How about by seeing through it all?

Learn how deep technical diligence and code analysis can cut through marketing spin, reveal structural flaws early, and separate genuine innovation from glossy vaporware. End of the day,code is law, even when the founders break it.
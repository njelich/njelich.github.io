---
# the default layout is 'page'
icon: fas fa-calendar
order: 6
---

{% assign current_date = "now" | date: "%s" %}
{% assign upcoming_events = site.data.sessions.events | where_exp: "event", "event.eventStartDate" %}
{% assign past_events = site.data.sessions.events | where_exp: "event", "event.eventStartDate" %}

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
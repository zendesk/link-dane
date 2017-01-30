import React, { PropTypes } from 'react'
import s from './Location.css'
import icons from '../../icons/css/icons.css'

import { relevantTaxonomies, getIcon } from '../../lib/taxonomies'
import { capitalize } from '../../lib/stringHelpers'

import Link from '../Link'
import GoogleMap from '../GoogleMap'

const getGender = (abbr) => {
  if (abbr === '' || abbr === 'MF' || abbr === 'FM') return 'Everyone'
  return abbr === 'F' ? 'Women' : 'Men'
}

const getGenderAdj = (abbr) => {
  if (abbr === '' || abbr === 'MF' || abbr === 'FM') {
    return 'All'
  }
  return abbr === 'F' ? 'Female' : 'Male'
}

const getAge = (abbr) => {
  switch (abbr) {
    case 'C':
      return 'children'
    case 'Y':
      return 'teens'
    case 'A':
      return 'adults'
    case 'S':
      return 'seniors'
    default:
      return ''
  }
}

const getAllGendersAndAges = (services) => {
  const allGendersAndAges = Object.values(services)
    .map(service => service.eligibility)
    .reduce((acc, eligibility) => {
      const { gender, age } = acc
      const moreGender = [...gender, eligibility.gender]
      const moreAge = eligibility.age ? [...age, ...eligibility.age] : age // ['C', 'Y']
      return { gender: moreGender, age: moreAge }
    }, { gender: [], age: [] })
  return {
    gender: Array.from(new Set(allGendersAndAges.gender)).join(''),
    age: Array.from(new Set(allGendersAndAges.age)),
  }
}

const getEligibility = ({ gender, age = [] }) => {
  if (gender === '' && age.length === 0) {
    return getGender(gender)
  }

  const ages = age.map(getAge).join(', ')

  return `${getGenderAdj(gender)} ${ages}`
}

const getMapsUrl = (location) => {
  const { latitude, longitude } = location
  return `https://maps.google.com/maps?q=loc:${latitude},${longitude}`
}

const DAYS = {
  0: 'sunday',
  1: 'monday',
  2: 'tuesday',
  3: 'wednesday',
  4: 'thursday',
  5: 'friday',
  6: 'saturday',
}

const DAY = {
  Sunday: 'sunday',
  Monday: 'monday',
  Tuesday: 'tuesday',
  Wednesday: 'wednesday',
  Thursday: 'thursday',
  Friday: 'friday',
  Saturday: 'saturday',
}

const DAY_ABBREVIATIONS = {
  sunday: 'Sun',
  monday: 'Mon',
  tuesday: 'Tue',
  wednesday: 'Wed',
  thursday: 'Thu',
  friday: 'Fri',
  saturday: 'Sat',
}

const convertMilitaryTime = (time) => {
  const hours = Math.floor(time / 100)
  const mins = time % 100
  let output = ''
  if (hours < 12) {
    if (hours == 0) {
      output += 12
    } else {
      output += hours
    }
    if (mins > 0) {
      output += `:${mins}`
    }
    output += 'am'
  } else {
    if (hours == 12) {
      output += hours
    } else {
      output += hours - 12
    }
    if (mins > 0) {
      output += `:${mins}`
    }
    output += 'pm'
  }
  return output
}

const getDailySchedules = (schedules) => {
  const daySchedules = Object.assign({}, DAY_ABBREVIATIONS)
  Object.keys(daySchedules).forEach(day => {
    daySchedules[day] = []
  })
  schedules
    .forEach(schedule => {
      if(schedule.opensAt != schedule.closesAt) { // Check if location is open
        const day = schedule.weekday.toLowerCase()
        const daySchedule = daySchedules[day]
        daySchedule.push({
          opensAt: schedule.opensAt,
          closesAt: schedule.closesAt,
        })
      }
    })
  return daySchedules
}

const getTimeRange = hours => (
  `${convertMilitaryTime(hours.opensAt)} - ${convertMilitaryTime(hours.closesAt)}`
)

const Schedule = (props) => {
  const daySchedules = getDailySchedules(props.schedules)
  const indexToDaySchedule = index => daySchedules[DAYS[index]]
  const dayHasSchedules = daySchedule => indexToDaySchedule(daySchedule).length > 0
  const scheduleRows = Object.keys(DAYS).sort()
    .filter(dayHasSchedules)
    .map(index => (
      <tr key={`day-${index}`}>
        <td className={s.labelHour}>
          <b>{DAY_ABBREVIATIONS[DAYS[index]]}:</b>
        </td>
        <td className={s.hour}>
          {indexToDaySchedule(index)
              .sort((a, b) => a.opensAt < b.opensAt)
              .map(getTimeRange)
              .join(', ')
          }
        </td>
      </tr>
    ))
  return (
    <table className={s.openHours}>
      <tbody>
        {scheduleRows}
      </tbody>
    </table>
  )
}

const Location = (props) => {
  const { location, organization } = props
  const { services = [] } = location
  return (
    <div className={s.location}>
      <div className={s.card}>
        <h2 className={s.name}>{location.name}</h2>
        <span className={s.label}>Welcome: </span>
          {getEligibility(getAllGendersAndAges(services))}
      </div>
      <div className={s.card}>
        <h1>Services</h1>
        <div className={s.categoryIcons}>
          {relevantTaxonomies(services).map((taxonomy, index) => (
            <span key={`category-${index}`}>
              <i className={`category-icon ${getIcon(taxonomy)}`}></i>
              {capitalize(taxonomy)}
            </span>
          ))}
        </div>
      </div>
      {location.physicalAddress &&
        <div className={`${s.card} ${s.map}`}>
          <a href={getMapsUrl(location)} rel="nofollow" target="_blank" title="Click to open Google Maps in a new window with directions to facility">
            <div className={s.detailMap}>
              <GoogleMap lat={location.latitude} long={location.longitude} />
            </div>
            <div className={s.getDirection}>
              <i className={`${icons.iconCompass} icon-compass`}></i>
              <span>Get Directions</span>
            </div>
          </a>
        </div>
      }
      <div className={s.card}>
        <h1>Contact Information</h1>
        <hr />
        {organization.phones &&
          <div className={s.inset + ' ' + s.insetInGroup}>
              <div className={s.callPhone}>
                 {organization.phones.map((phone, index) => (
                  <a href={'tel:' + phone.number.replace(/[^\d]/g, '')} key={`phone-${index}`}>
                    <i className={`${icons.iconPhone} icon-phone`}></i>
                    {phone.number}
                    <span className={s.phoneDepartment}>{phone.department}</span>
                    <label>Call Now</label>
                  </a>
                ))}
              </div>
          </div>
        }
        {organization.url &&
          <a href={organization.url} className={s.inset + ' ' + s.insetInGroup}>
            <i className={`${icons.iconLink} icon-link`}></i>
            <span className={s.websiteUrl}>{organization.url}</span>
            <label>Visit Website</label>
          </a>
        }
        <a href={getMapsUrl(location)} rel="nofollow" target="_blank" className={s.inset + ' ' + s.insetInGroup}>
            <i className={`${icons.iconCompass} icon-compass`}></i>
            <span>{location.physicalAddress.address1}</span>
            <label>Directions</label>
        </a>
      </div>
      {services && Object.values(services).map((service, index) => (
        <div key={`service-${index}`} className={s.card + ' ' + s.insetServices}>
          <div className={s.serviceInset}>
            <h3 className={s.serviceTitle}>{service.name}</h3>
            <p className={s.serviceDescription}>{service.description}</p>
          </div>
          {service.eligibilityNote && <div className={s.eligibilityNote}>
            <strong><label>Eligibility Notes:</label></strong>
            <p>{service.eligibilityNote}</p>
          </div>}
          <div className={s.serviceInset}>
            <strong><label>Hours:</label></strong><br/>
            <Schedule schedules={service.schedules} />
          </div>
          {service.schedulesNote && <div className={s.schedulesNote}>
            <i className={`${icons.iconAttention} icon-attention`}></i>
            <strong><label>Hours Notes:</label></strong>
            <p>{service.schedulesNote}</p>
          </div>}
          <div className={s.notes}>
            <strong><label>Notes:</label></strong>
            <p>{service.applicationProcess}</p>
          </div>
        </div>
      ))}
    </div>
  )
}

export default Location

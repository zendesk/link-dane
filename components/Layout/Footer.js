import React from 'react'
import Link from '../Link'
import s from './Footer.css'

class Footer extends React.Component {
  render() {
    return (
      <footer className={s.footer} role="navigation">
        <a title="Calls 211 for additional help" href="tel:211">Call 211</a>
        <Link className={s.nav} to="/terms">
          Terms
        </Link>
        <a title="Provide feedback about Link-Dane" href="mailto:support@linkdane.zendesk.com">Feedback</a>
        <Link className={s.nav} to="/about">
          About
        </Link>
      </footer>
    )
  }

}

export default Footer

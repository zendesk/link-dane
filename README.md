## Link-Dane

### Open Referral Transition
This version of link-dane is currently undergoing a data model transition to be HSDS compliant.

#### [In Active Development] Current Boilerplate

Project structure based on https://github.com/koistya/react-static-boilerplate

http://link-dane.co

A mobile website designed to connect those in need in Dane County, WI to the services that can help them, on their own terms.

Link-Dane is a single page React.js application using [Firebase](https://www.firebase.com/) for persistence. Querying is done in the front-end in order to maintain a mostly backend agnostic application.

Documentation is available under `docs` for offline viewing or via links below:

* [Setup](https://github.com/zendesk/linksf/blob/master/docs/SETUP.md)
* [Design](https://github.com/zendesk/linksf/blob/master/docs/DESIGN.md)
* [Deploy](https://github.com/zendesk/linksf/blob/master/docs/DEPLOY.md)
* [Managing facilities and services](https://github.com/zendesk/linksf/blob/master/docs/MANAGE.md)

Link-Dane is an ongoing collaboration between the [United Way of Dane County](https://www.unitedwaydanecounty.org/) and [Zendesk, Inc](http://www.zendesk.com/).

### History

Link-Dane is a mobile web app designed to give this growing community of smartphone users instant access to relevant services on the go by surfacing crucial information like open hours, phone numbers, and Google Maps directions.

Link-Dane is based on [Link SF](https://github.com/zendesk/linksf).

Contact us at [support@linkdane.zendesk.com](mailto:support@linkdane.zendesk.com).

### Note
In January 2016, Facebook [announced](http://blog.parse.com/announcements/moving-on/) the impending shutdown of the Parse service. Since that time, our team has been working on creating a new solution for all instances of the Link-SF project that does not rely on Parse. Our secondary mission for Version 2 is to support data which is in the [OpenReferral format](https://openreferral.org/) and inspired by the [Ohana API](https://github.com/codeforamerica/ohana-api). This current version uses firebase as a backend and React for the front-end.

For users of our previous version (still available at [this branch](https://github.com/zendesk/link-dane/tree/parse-version), we are also building a migrator to help transition to the new version. Contact us at [support@linkdane.zendesk.com](mailto:support@linkdane.zendesk.com) if you need assistance during this phase.

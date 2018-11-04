Release Naming
---
Our release names are time-based and follow a `yy.mm(.respin)` notation. 
Eg `Release 18.10` should happen in October of 2018.
Hotfix/respins are denoted by an increasing trailing number if needed. Eg `Release 18.10.1`, `Release 18.10.2` and so on.

Release Schedule
---
We aim for a release on the first Monday of each month. This is manual right now, but ideally, it will be automated.
Monday was selected because emulator use peaks on the weekends, so we have 5 days to fix things up/rollback if a bad release happens.

Release Planning
---
We have milestones for 3 releases ahead, then [Mid Term Goals](https://github.com/reicast/reicast-emulator/milestone/4) for 3-9 months ahead, and [Long Term Goals](https://github.com/reicast/reicast-emulator/milestone/2) for 9+ months ahead.

Tickets are assigned to milestones based on a combination of feature planning and developer availability.

Feature "Freeze" Windows
---
We do a soft "feature freeze" on the week before release, to allow for the beta builds to be tested.
During this window, experimental/untested changes should not be merged.

Release Testing / QA
---
We depend on the public beta and people complaining right now. 
If you're interested to do QA testing around releases, please let us know in #1225, and/or join our [discord](http://chat.reicast.com)

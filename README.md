PagerBot [![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/stripe-contrib/pagerbot) [![Build Status](https://travis-ci.org/stripe-contrib/pagerbot.svg?branch=master)](https://travis-ci.org/stripe-contrib/pagerbot)
========

Pagerbot makes managing [PagerDuty](http://www.pagerduty.com/) on-call schedules easier. It currently supports IRC and Slack, and can be easily deployed to Heroku.

Pagerbot uses [Chronic](https://github.com/mojombo/chronic) for natural language date and time parsing.

Sample
=====

![ScreenShot](public/pics/animation.gif)

Usage
======

The easiest way to get started is to use the Heroku button above to launch an admin interface for pagerbot, where you need to fill out a few API keys and choose commands (plugins) that pagerbot knows about and responds to.

Going through the admin page shouldn't take much longer than 8 minutes. The admin page also contains detailed information on how to make the bot join your channel.

Modes and worker scheme
=======================

Pagerbot can be run in several modes:

- `admin` mode runs the admin webface.
- `slack` or `irc` modes connect to the respective services and don't run a web
  server for incoming requests.
- `hipchat` mode runs the bot with the hipchat adapter which runs a web server
  for incoming webhooks.
- `web` mode has it run in either admin or non-admin mode, depending on the
  `DEPLOYED` env var. In non-admin mode it uses addition command line args or
  config values to determine which bot type it is. This mode is only useful for
  hipchat at this point and maybe we should deprecate it.

Plugins
=======

Currently pagerbot supports the following commands (prefix all of them with bot name and a colon, e.g. `pagerbot:`):

| Plugin | Example | Notes |
| ----------------- |:---------------------------------------------------:| -----|
| - | `help` | Short list of all commands pagerbot knows. |
| - | `manual` | Show in-depth explanation about each command. |
| - | `who is on primary now?` | Find out who is on a specific schedule at time. |
| - | `when am I on product?` | Find out who is on a specific schedule at time. |
| Schedule override | `put me on triage for 30 minutes` | Overrides the current schedule for a duration. |
| Schedule override | `put carl on primary from 3 AM until 4 AM August 24th` | |
| Call | `call sys because admin server is acting funky` | Send email to \<teamname\>\<email-suffix\>, where email-suffix is set in admin. |
| Call person | `get andrew because we need to credential people` | Triggers an pagerduty issue for person. |
| Switch shift | `put amy on triage during carl's shift on August 11th` | Take over a single shift on a specific day. |
| Reload | `reload` | Load user and schedule changes from pagerduty. |
| Add Alias | `alias karl@mycompany.com as karl` | Add a new alias for person or schedule. |

Local development
=============

You will need ruby with bundle, as well as a running instance of mongodb running on port 27017.

Fork and clone this repository and open it in a console.

```bash
# running tests
rake test

# running the admin interface
bundle exec ruby lib/pagerbot.rb admin

# run irc bot locally (after setting up bot in admin)
bundle exec ruby lib/pagerbot.rb admin irc
```

To deploy it to heroku, git clone, create a heroku app and push to launch it.
```bash
heroku create
heroku addons:add mongolab:sandbox
git push heroku master
```

For developing new capabilities, PagerDuty has two different APIs:

* The [Integration API](https://developer.pagerduty.com/documentation/integration/events) is a high-availability endpoint for triggering and updating incidents.
* The [REST API](https://developer.pagerduty.com/documentation/rest) provides CRUD for most PagerDuty account objects, such as users, schedules, escalation policies, etc

FAQ
====

### Heroku is asking for my credit card! Do I need to pay for this?

No, running your own pagerbot is free! This is a requirement of the free MongoDB add-on. See the [verification policy of Heroku](https://devcenter.heroku.com/articles/account-verification#verification-requirement).

### How can I secure the admin interface?

Set the enviroment variable called `PROTECT_ADMIN` to be your desired password. Instructions for changing an enviroment variable are listed in the next FAQ.

When using the admin interface, enter the same password, the username can be arbitrary.

### How can I relaunch the admin interface?

Via web:
* [Log into heroku](https://dashboard.heroku.com/) and navigate to your application.
* Remove the DEPLOYED config variable if present.
* Scale web workers to 1 and the others to 0.

Via command line:
* `heroku config:unset DEPLOYED`
* `heroku ps:scale web=1 irc=0 slack=0`

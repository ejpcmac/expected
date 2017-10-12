# Expected

Expected is an Elixir module for login and session management. It enables
persistent login through a cookie, following Barry Jaspan’s
[Improved Persistent Login Cookie Best Practice](http://www.jaspan.com/improved_persistent_login_cookie_best_practice),
and adds the ability to remotely discard sessions. For this to work with current
sessions, your session store must be server-side, like
[`plug_session_mnesia`](https://github.com/ejpcmac/plug_session_mnesia).

**This project is not released at the time. To see ongoing development, please
take a look at the `develop` branch.**

## Roadmap

* Login struct
* Store behaviour (GenServer for tests, Mnesia)
* Creation plug
* Authentication plug
* API to manage current logins (list, invalidate)

## [Contributing](CONTRIBUTING.md)

Before to contribute on this project, please read the
[CONTRIBUTING.md](CONTRIBUTING.md).

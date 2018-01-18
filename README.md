# Expected

[![hex.pm version](http://img.shields.io/hexpm/v/expected.svg?style=flat)](https://hex.pm/packages/expected)

Expected is an Elixir application for login and session management. It enables
persistent logins through a cookie, following Barry Jaspan’s
[Improved Persistent Login Cookie Best Practice](http://www.jaspan.com/improved_persistent_login_cookie_best_practice).
It also provides an API to list and discard sessions.

## Setup

To use Expected in your app, add this to your dependencies:

```elixir
{:expected, "~> 0.1.0"}
```

### Configuration

You must configure Expected in your `config.exs`, for instance:

```elixir
config :expected,
  store: :mnesia,
  table: :logins,
  auth_cookie: "_my_app_auth",
  session_store: PlugSessionMnesia.Store,
  session_cookie: "_my_app_key"
```

The mandatory fields are the following:

* `store` - the login store
* `auth_cookie` - the persistent authentication cookie name
* `session_store` - the session store passed to `Plug.Session`
* `session_cookie` - the `key` option for `Plug.Session`

There are also some optional fields:

* `cookie_max_age` - the authentication cookie max age is seconds (default:
  90 days)
* `cleaner_period` - the login cleaner period in seconds (default: 1 day)
* `session_opts` - options passed to `Plug.Session`
* `plug_config` - options passed to the plugs in
  [`Expected.Plugs`](https://hexdocs.pm/expected/Expected.Plugs.html)

#### Login store

Currently, the built-in stores are `:mnesia` and `:memory`. `:memory` is for
testing purpose only, so please use `:mnesia`. An official `:ecto` one could
come some day; feel free to ask me if you need it or plan to implement it. You
can also implement another store using the
[`Expected.Store` specifications](https://hexdocs.pm/expected/Expected.Store.html).

For the `:mnesia` store, you need to add a `:table` option to set the Mnesia
table where to store logins. Then, ask mix to create the table for you:


    $ mix expected.mnesia.setup

If you want to use a node name or a custom directory for the Mnesia database,
you can take a look at
[`Mix.Tasks.Expected.Mnesia.Setup`](https://hexdocs.pm/expected/Mix.Tasks.Expected.Mnesia.Setup.html).

You can also create it directly from Elixir using
[`Expected.MnesiaStore.Helpers.setup!/0`](https://hexdocs.pm/expected/Expected.MnesiaStore.Helpers.html#setup!/0).
This can be useful to include in a setup task to be run in a release
environment.

#### Authentication cookie

The authentication cookie contains the username, a serial and a token
seperated by dots. The token is usable only once, and is renewed on each
successful authentication.

By default, the authentication cookie is valid for 90 days after the last
successful authentication. This can be configured using the `cookie_max_age`
option in the configuration.

To avoid old logins to accumulate in the store, inactive logins older than the
`cookie_max_age` are automatically cleaned by
[`Expected.Cleaner`](https://hexdocs.pm/expected/Expected.Cleaner.html) once a
day. You can change this period by setting `cleaner_period` (in seconds) in the
application configuration.

#### Session store

Expected calls `Plug.Session` itself. Therefore, you need to set the session
store in the Expected configuration. For the session management to work, **it
must be a server-side session store that stores the session ID in the session
cookie**. I’ve written
[`plug_session_mnesia`](https://hex.pm/packages/plug_session_mnesia), but you
can use whatever server-side session store you want.

The `session_cookie` field is passed as `key` to `Plug.Session`. Every other
specific options you would need to pass to `Plug.Session` must be written in
a `session_opts` list. For example, to set the table for the `:ets` session
store:

```elixir
config :expected,
  ...
  session_store: :ets,
  session_opts: [table: :session],
  session_cookie: "_my_app_auth"
```

* * *

You must plug `Expected` in you endpoint, and do **not** plug `Plug.Session`
yourself:

```elixir
# Plug Expected
plug Expected

# Do NOT plug Plug.Session
# plug Plug.Session,
#   store: PlugSessionMnesia.Store,
#   key: "_my_app_key"
```

Then, in your pipeline, plug `Expected.Plugs.authenticate/2`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # Import the authenticate/2 plug
  import Expected.Plugs, only: [authenticate: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :authenticate  # Plug it after fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  ...
end
```

## Login registration

To register a login, use `Expected.Plugs.register_login/2` in your login
pipeline, for instance:

```elixir
case Auth.authenticate(username, password) do
  {:ok, user} ->
    conn
    |> put_session(:authenticated, true)
    |> put_session(:current_user, user)
    |> register_login()  # Call register_login here
    |> redirect(to: page)

  :error ->
    ...
end
```

To associate the login with a user, `register_login/2` expects a
`:current_user` key featuring a `:username` field in the session. For more
information and configuration options, please look at
[`Expected.Plugs.register_login/2`](https://hexdocs.pm/expected/Expected.Plugs.html#register_login/2)
in the documentation.

## Authentication

When `Expected.Plugs.authenticate/2` is called in the pipeline, it does the
following things:

1. It checks wether the session is authenticated, *i.e.* the
   `:authenticated` key is set to `true`. If it is the case, it assigns
   `:authenticated` and `:current_user` in the connection according to their
   values in the session, and does nothing more.

2. If the session is not authenticated, it checks for an authentication
   cookie. If there is no authentication cookie, it does nothing more.

3. If there is an authentication cookie, it checks for a login matching with
   the username and serial in the store. If the cookie is invalid or there
   is no login in the store, it just deletes the cookie and does nothing
   more.

4. If there is a matching login, it checks wether the token matches. If it
   is the case, it sets `:authenticated` to `true` and `:current_user` to an
   `Expected.NotLoadedUser` in both the session and the connection assigns.
   If the token does not match, it deletes all the users’s logins and
   sessions, puts a flag in the connection assigns, deletes the cookie and
   does not authenticate.

## User loading

Expected does not makes any assumptions regarding your user module or how to
load it from the database. When authenticating from a cookie, it puts an
`Expected.NotLoadedUser` with the username matching the one in the cookie in
both the session and the connection assings.

If you want the user to be loaded in the session and/or the connection
assigns, you should write a plug to do so:

```elixir
@spec load_user(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
def load_user(conn, _opts \\\\ []) do
  case conn.assigns[:current_user] do
    # If there has been a successful authentication, there is a
    # NotLoadedUser in the connection assigns.
    %Expected.NotLoadedUser{username: username} ->
      # Get the user from the database.
       user = Accounts.get_user!(username)

       # Replace the NotLoadedUser with the loaded one in both the session
       # and the connection assigns.
       conn
       |> put_session(:current_user, user)
       |> assign(:current_user, user)

    # If there is no user to load, do nothing.
    _ ->
      conn
  end
end
```

Then, plug it in your pipeline:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :authenticate
  plug :load_user  # Plug it after authenticate
  plug :fetch_flash
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end
```

## Unexpected token

A token mismatch generally means an old token has been reused. It basically
can arrive in two situations:

1. the user has rolled back a backup or has cloned his browser profile,
2. the user tries to authenticate after some malicious people have stolen
   the cookie and already authenticated with it.

In the assumption we are in the case (2), all the user’s sessions are deleted
and a flag is put in the connection assigns. You can check after an
authentication attempt if there has been an unexpected token using
`Expected.unexpected_token?/1`. It’s up to you to choose wether you should
show an alert to the user. Do not forget to state it can be due to case (1).

## Logout

To log a user out, simply call `Expected.Plugs.logout/2` on the connection. It
will delete the login and its associated session from the stores and their
cookies. For instance, you can imagine the following action for your session
controller:

```elixir
import Expected.Plugs, only: [logout: 1]

@spec delete(Plug.Conn.t, map) :: Plug.Conn.t
def delete(conn, _params) do
  conn
  |> logout()
  |> redirect(to: "/")
end
```

## [Contributing](CONTRIBUTING.md)

Before to contribute on this project, please read the
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright © 2018 Jean-Philippe Cugnet

This project is licensed under the [MIT license](LICENSE).

import Config

config :logger, :console, colors: [enabled: false]

config :phoenix_view, :json_library, Jason

config :phoenix_view, :trim_on_html_eex_engine, false

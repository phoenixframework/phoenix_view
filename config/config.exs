import Config

config :logger, :console, colors: [enabled: false]
config :phoenix_template, :json_library, Jason
config :phoenix_template, :trim_on_html_eex_engine, false

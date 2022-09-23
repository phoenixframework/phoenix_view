import Config

config :logger, :console, colors: [enabled: false]

# TODO: Rename those to :phoenix_template once it is extrated
config :phoenix_view, :json_library, Jason
config :phoenix_view, :trim_on_html_eex_engine, false

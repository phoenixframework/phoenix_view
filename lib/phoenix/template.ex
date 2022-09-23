defmodule Phoenix.Template do
  @moduledoc """
  Templates are used by Phoenix when rendering responses.

  Since many views render significant content, for example a whole
  HTML file, it is common to put these files into a particular directory,
  typically "APP_web/templates".

  This module provides conveniences for reading all files from a
  particular directory and embedding them into a single module.

  `Phoenix.Template` will define a private function named `render_template/2`
  with one clause per file system template. You are responsible to expose
  it appropriately, as shown above.

  In practice, developers rarely use `Phoenix.Template` directly.
  Instead they use `Phoenix.View` which wraps the template functionality
  and adds some extra conveniences.

  ## Custom Template Engines

  Phoenix supports custom template engines. Engines tell
  Phoenix how to convert a template path into quoted expressions.
  See `Phoenix.Template.Engine` for more information on
  the API required to be implemented by custom engines.

  Once a template engine is defined, you can tell Phoenix
  about it via the template engines option:

      config :phoenix, :template_engines,
        eex: Phoenix.Template.EExEngine,
        exs: Phoenix.Template.ExsEngine

  ## Format encoders

  Besides template engines, Phoenix has the concept of format encoders.
  Format encoders work per format and are responsible for encoding a
  given format to string once the view layer finishes processing.

  A format encoder must export a function called `encode_to_iodata!/1`
  which receives the rendering artifact and returns iodata.

  New encoders can be added via the format encoder option:

      config :phoenix_template, :format_encoders,
        html: Phoenix.HTML.Engine

  """

  @type path :: binary
  @type root :: binary

  @default_pattern "*"

  ## Configuration API

  @engines [
    eex: Phoenix.Template.EExEngine,
    exs: Phoenix.Template.ExsEngine,
    leex: Phoenix.LiveView.Engine,
    heex: Phoenix.LiveView.HTMLEngine
  ]

  @doc """
  Returns the format encoder for the given template.
  """
  @spec format_encoder(path) :: module | nil
  def format_encoder(path) when is_binary(path) do
    Map.get(compiled_format_encoders(), Path.extname(path))
  end

  defp compiled_format_encoders do
    case Application.fetch_env(:phoenix_view, :compiled_format_encoders) do
      {:ok, encoders} ->
        encoders

      :error ->
        encoders =
          default_encoders()
          |> Keyword.merge(raw_config(:format_encoders, []))
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{}, fn {k, v} -> {".#{k}", v} end)

        Application.put_env(:phoenix_view, :compiled_format_encoders, encoders)
        encoders
    end
  end

  defp default_encoders do
    [html: Phoenix.HTML.Engine, json: json_library(), js: Phoenix.HTML.Engine]
  end

  defp json_library() do
    Application.get_env(:phoenix_template, :json_library) ||
    deprecated_config(:phoenix_view, :json_library) ||
      Application.get_env(:phoenix, :json_library, Jason)
  end

  @doc """
  Returns a keyword list with all template engines
  extensions followed by their modules.
  """
  @spec engines() :: %{atom => module}
  def engines do
    compiled_engines()
  end

  defp compiled_engines do
    case Application.fetch_env(:phoenix_view, :compiled_template_engines) do
      {:ok, engines} ->
        engines

      :error ->
        engines =
          @engines
          |> Keyword.merge(raw_config(:template_engines, []))
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{})

        Application.put_env(:phoenix_view, :compiled_template_engines, engines)
        engines
    end
  end

  defp raw_config(name, fallback) do
    Application.get_env(:phoenix_template, name) ||
    deprecated_config(:phoenix_view, name) || Application.get_env(:phoenix, name, fallback)
  end

  defp deprecated_config(app, name) do
    if value = Application.get_env(app, name) do
      # TODO: Uncomment once :phoenix_template is extracted
      # IO.warn(
      #   "config :#{app}, :#{name} is deprecated, please use config :phoenix_template, :#{name} instead"
      # )

      value
    end
  end

  ## Lookup API

  @doc """
  Returns all template paths in a given template root.
  """
  @spec find_all(root, pattern :: String.t(), %{atom => module}) :: [path]
  def find_all(root, pattern \\ @default_pattern, engines \\ engines()) do
    extensions = engines |> Map.keys() |> Enum.join(",")

    root
    |> Path.join(pattern <> ".{#{extensions}}")
    |> Path.wildcard()
  end

  @doc """
  Returns the hash of all template paths in the given root.

  Used by Phoenix to check if a given root path requires recompilation.
  """
  @spec hash(root, pattern :: String.t(), %{atom => module}) :: binary
  def hash(root, pattern \\ @default_pattern, engines \\ engines()) do
    find_all(root, pattern, engines)
    |> Enum.sort()
    |> :erlang.md5()
  end

  defp compile(path, root, engines) do
    name = template_path_to_name(path, root)
    defp = String.to_atom(name)
    ext = Path.extname(path) |> String.trim_leading(".") |> String.to_atom()
    engine = Map.fetch!(engines, ext)
    quoted = engine.compile(path, name)

    {name, engine,
     quote do
       @file unquote(path)
       @external_resource unquote(path)

       defp unquote(defp)(var!(assigns)) do
         _ = var!(assigns)
         unquote(quoted)
       end

       defp render_template(unquote(name), assigns) do
         unquote(defp)(assigns)
       end
     end}
  end

  ## Deprecated API

  @deprecated "Use Phoenix.View.template_path_to_name/3"
  def template_path_to_name(path, root) do
    path
    |> Path.rootname()
    |> Path.relative_to(root)
  end

  @deprecated "Use Phoenix.View.module_to_template_root/3"
  def module_to_template_root(module, base, suffix) do
    module
    |> unsuffix(suffix)
    |> Module.split()
    |> Enum.drop(length(Module.split(base)))
    |> Enum.map(&Macro.underscore/1)
    |> join_paths()
  end

  defp join_paths([]), do: ""
  defp join_paths(paths), do: Path.join(paths)

  defp unsuffix(value, suffix) do
    string = to_string(value)
    suffix_size = byte_size(suffix)
    prefix_size = byte_size(string) - suffix_size

    case string do
      <<prefix::binary-size(prefix_size), ^suffix::binary>> -> prefix
      _ -> string
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    root = Module.get_attribute(env.module, :phoenix_root)
    pattern = Module.get_attribute(env.module, :phoenix_pattern)
    engines = Module.get_attribute(env.module, :phoenix_template_engines)

    triplets =
      for path <- find_all(root, pattern, engines) do
        compile(path, root, engines)
      end

    names = Enum.map(triplets, &elem(&1, 0))
    codes = Enum.map(triplets, &elem(&1, 2))

    compile_time_deps =
      for engine <- triplets |> Enum.map(&elem(&1, 1)) |> Enum.uniq() do
        quote do
          unquote(engine).__info__(:module)
        end
      end

    quote do
      unquote(compile_time_deps)
      unquote(codes)

      # Catch-all clause for template rendering.
      defp render_template(template, %{__phx_render_existing__: {__MODULE__, template}}) do
        nil
      end

      defp render_template(template, %{__phx_template_not_found__: __MODULE__} = assigns) do
        Phoenix.View.__not_found__!(__MODULE__, template, assigns)
      end

      defp render_template(template, assigns) do
        template_not_found(template, Map.put(assigns, :__phx_template_not_found__, __MODULE__))
      end

      @doc false
      def __templates__ do
        {@phoenix_root, @phoenix_pattern, unquote(names)}
      end

      @doc false
      def __mix_recompile__? do
        unquote(hash(root, pattern, engines)) !=
          Phoenix.Template.hash(@phoenix_root, @phoenix_pattern, @phoenix_template_engines)
      end
    end
  end
end

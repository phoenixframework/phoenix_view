defmodule Phoenix.View do
  @moduledoc """
  Defines the view layer of a Phoenix application.

  The view layer contains conveniences for rendering templates,
  including support for layouts and encoders per format.

  ## Examples

  Phoenix defines the view template at `lib/your_app_web.ex`:

      defmodule YourAppWeb do
        # ...

        def view do
          quote do
            use Phoenix.View, root: "lib/your_app_web/templates", namespace: YourAppWeb

            # Import convenience functions from controllers
            import Phoenix.Controller,
              only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

            # Use all HTML functionality (forms, tags, etc)
            use Phoenix.HTML

            import YourAppWeb.ErrorHelpers
            import YourAppWeb.Gettext

            # Alias the Helpers module as Routes
            alias  YourAppWeb.Router.Helpers, as: Routes
          end
        end

        # ...
      end

  You can use the definition above to define any view in your application:

      defmodule YourApp.UserView do
        use YourAppWeb, :view
      end

  Because we have defined the template root to be "lib/your_app_web/templates",
  `Phoenix.View` will automatically load all templates at "your_app_web/templates/user"
  and include them in the `YourApp.UserView`. For example, imagine we have the
  template:

      # your_app_web/templates/user/index.html.heex
      Hello <%= @name %>

  The `.heex` extension maps to a template engine which tells Phoenix how
  to compile the code in the file into Elixir source code. After it is
  compiled, the template can be rendered as:

      Phoenix.View.render_to_string(YourApp.UserView, "index.html", name: "John Doe")
      #=> "Hello John Doe"

  ## Differences to `Phoenix.LiveView`

  Traditional web applications, that rely on a request/response life cycle,
  have been typically organized under the Model-View-Controller pattern.
  In this case, the Controller is responsible for organizing interacting
  with the model and passing all relevant information to the View for
  rendering. `Phoenix.Controller` and `Phoenix.View` play those roles
  respectively.

  `Phoenix.LiveView` introduces a declarative model where the controller
  and the view are kept side by side. This empowers `Phoenix.LiveView`
  to provide realtime and interactive features under a stateful connection.

  In other words, you may consider that `Phoenix.LiveView` abridges both
  `Phoenix.Controller` and `Phoenix.View` responsibilities. Developers
  do not generally use `Phoenix.View` from their live views, but LiveView
  does use `Phoenix.View` and its features under the scenes.

  ## Rendering and formats

  The main responsibility of a view is to render a template.

  A template has a name, which also contains a format. For example,
  in the previous section we have rendered the "index.html" template:

      Phoenix.View.render_to_string(YourApp.UserView, "index.html", name: "John Doe")
      #=> "Hello John Doe"

  While we got a string at the end, that's not actually what our templates
  render. Let's take a deeper look:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> ...

  This inner representation allows us to separate how templates render and
  how they are encoded. For example, if you want to render JSON data, we
  could do so by adding a "show.json" entry to `render/2` in our view:

      defmodule YourApp.UserView do
        use YourApp.View

        def render("show.json", %{user: user}) do
          %{name: user.name, address: user.address}
        end
      end

  Notice that in order to render JSON data, we don't need to explicitly
  return a JSON string! Instead, we just return data that is encodable to
  JSON. Now, when we call:

      Phoenix.View.render_to_string(YourApp.UserView, "user.json", user: %User{...})

  Because the template has the `.json` extension, Phoenix knows how to
  encode the map returned for the "user.json" template into an actual
  JSON payload to be sent over the wire.

  Phoenix ships with some template engines and format encoders, which
  can be further configured in the Phoenix application. You can read
  more about format encoders in `Phoenix.Template` documentation.
  """

  alias Phoenix.{Template}

  @doc """
  When used, defines the current module as a main view module.

  ## Options

    * `:root` - the template root to find templates
    * `:path` - the optional path to search for templates within the `:root`.
      Defaults to the underscored view module name. A blank string may
      be provided to use the `:root` path directly as the template lookup path
    * `:namespace` - the namespace to consider when calculating view paths
    * `:pattern` - the wildcard pattern to apply to the root
      when finding templates. Default `"*"`

  The `:root` option is required while the `:namespace` defaults to the
  first nesting in the module name. For instance, both `MyApp.UserView`
  and `MyApp.Admin.UserView` have namespace `MyApp`.

  The `:namespace` and `:path` options are used to calculate template
  lookup paths. For example, if you are in `MyApp.UserView` and the
  namespace is `MyApp`, templates are expected at `Path.join(root, "user")`.
  On the other hand, if the view is `MyApp.Admin.UserView`,
  the path will be `Path.join(root, "admin/user")` and so on. For
  explicit root path locations, the `:path` option can be provided instead.
  The `:root` and `:path` are joined to form the final lookup path.
  A blank string may be provided to use the `:root` path directly as the
  template lookup path.

  Setting the namespace to `MyApp.Admin` in the second example will force
  the template to also be looked up at `Path.join(root, "user")`.
  """
  defmacro __using__(opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote do
      import Phoenix.View
      use Phoenix.Template, Phoenix.View.__template_options__(__MODULE__, unquote(opts))

      @before_compile Phoenix.View

      @doc """
      Renders the given template locally.
      """
      def render(template, assigns \\ %{})

      def render(module, template) when is_atom(module) do
        Phoenix.View.render(module, template, %{})
      end

      def render(template, _assigns) when not is_binary(template) do
        raise ArgumentError, "render/2 expects template to be a string, got: #{inspect(template)}"
      end

      def render(template, assigns) when not is_map(assigns) do
        render(template, Enum.into(assigns, %{}))
      end

      @doc "The resource name, as an atom, for this view"
      def __resource__, do: @view_resource
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  @doc false
  defmacro __before_compile__(_env) do
    # We are using @anno because we don't want warnings coming from
    # render/2 to be reported in case the user has defined a catch-all
    # render/2 clause.
    quote generated: true do
      # Catch-all clause for rendering.
      def render(template, assigns) do
        render_template(template, assigns)
      end
    end
  end

  @doc """
  Renders the given layout passing the given `do/end` block
  as `@inner_content`.

  This can be useful to implement nested layouts. For example,
  imagine you have an application layout like this:

      # layout/app.html.heex
      <html>
      <head>
        <title>Title</title>
      </head>
      <body>
        <div class="menu">...</div>
        <%= @inner_content %>
      </body>

  This layout is used by many parts of your application. However,
  there is a subsection of your application that wants to also add
  a sidebar. Let's call it "blog.html". You can build on top of the
  existing layout in two steps. First, define the blog layout:

      # layout/blog.html.heex
      <%= render_layout LayoutView, "app.html", assigns do %>
        <div class="sidebar">...</div>
        <%= @inner_content %>
      <% end %>

  And now you can simply use it from your controller:

      plug :put_layout, "blog.html"

  """
  def render_layout(module, template, assigns, do: block) do
    assigns =
      assigns
      |> Map.new()
      |> Map.put(:inner_content, block)

    module.render(template, assigns)
  end

  @doc """
  Renders a template.

  It expects the view module, the template as a string, and a
  set of assigns.

  Notice that this function returns the inner representation of a
  template. If you want the encoded template as a result, use
  `render_to_iodata/3` instead.

  ## Examples

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  ## Assigns

  Assigns are meant to be user data that will be available in templates.
  However, there are keys under assigns that are specially handled by
  Phoenix, they are:

    * `:layout` - tells Phoenix to wrap the rendered result in the
      given layout. See next section

  ## Layouts

  Templates can be rendered within other templates using the `:layout`
  option. `:layout` accepts a tuple of the form
  `{LayoutModule, "template.extension"}`.

  To template that goes inside the layout will be placed in the `@inner_content`
  assign:

      <%= @inner_content %>

  """
  def render(module, template, assigns)

  def render(module, template, assigns) do
    assigns
    |> Map.new()
    |> Map.pop(:layout, false)
    |> render_within(module, template)
  end

  defp render_within({false, assigns}, module, template) do
    module.render(template, assigns)
  end

  defp render_within({{layout_mod, layout_tpl}, assigns}, module, template)
       when is_atom(layout_mod) and is_binary(layout_tpl) do
    content = module.render(template, assigns)
    assigns = Map.put(assigns, :inner_content, content)
    layout_mod.render(layout_tpl, assigns)
  end

  defp render_within({layout, _assigns}, _module, _template) do
    raise ArgumentError, """
    invalid value for reserved key :layout in View.render/3 assigns

    :layout accepts a tuple of the form {LayoutModule, "template.extension"}

    got: #{inspect(layout)}
    """
  end

  @doc ~S'''
  Renders a template only if it exists.

  > Note: Using this functionality has been discouraged in
  > recent Phoenix versions, see the "Alternatives" section
  > below.

  This function works the same as `render/3`, but returns
  `nil` instead of raising. This is often used with
  `Phoenix.Controller.view_module/1` and `Phoenix.Controller.view_template/1`,
  which must be imported into your views. See the "Examples"
  section below.

  ## Alternatives

  This function is discouraged. If you need to render something
  conditionally, the simplest way is to check for an optional
  function in your views.

  Consider the case where the application has a sidebar in its
  layout and it wants certain views to render additional buttons
  in the sidebar. Inside your sidebar, you could do:

      <div class="sidebar">
        <%= if function_exported?(view_module(@conn), :sidebar_additions, 1) do
          <%= view_module(@conn).sidebar_additions(assigns) %>
        <% end %>
      </div>

  If you are using Phoenix.LiveView, you could do similar by
  accessing the view under `@socket`:

      <div class="sidebar">
        <%= if function_exported?(@socket.view, :sidebar_additions, 1) do
          <%= @socket.view.sidebar_additions(assigns) %>
        <% end %>
      </div>

  Then, in your view or live view, you do:

      def sidebar_additions(assigns) do
        ~H\"""
        ...my additional buttons...
        \"""

  ## Using render_existing

  Consider the case where the application wants to allow entries
  to be added to a sidebar. This feature could be achieved with:

      <%= render_existing view_module(@conn), "sidebar_additions.html", assigns %>

  Then the module under `view_module(@conn)` can decide to provide
  scripts with either a precompiled template, or by implementing the
  function directly, ie:

      def render("sidebar_additions.html", _assigns) do
        ~H"""
        ...my additional buttons...
        """
      end

  To use a precompiled template, create a `scripts.html.eex` file in
  the `templates` directory for the corresponding view you want it to
  render for. For example, for the `UserView`, create the `scripts.html.eex`
  file at `your_app_web/templates/user/`.
  '''
  @deprecated "Use function_exported?/3 instead"
  def render_existing(module, template, assigns \\ []) do
    assigns = assigns |> Map.new() |> Map.put(:__phx_render_existing__, {module, template})
    render(module, template, assigns)
  end

  @doc """
  Renders a collection.

  A collection is any enumerable of structs. This function
  returns the rendered collection in a list:

      render_many users, UserView, "show.html"

  is roughly equivalent to:

      Enum.map(users, fn user ->
        render(UserView, "show.html", user: user)
      end)

  The underlying user is passed to the view and template as `:user`,
  which is inferred from the view name. The name of the key
  in assigns can be customized with the `:as` option:

      render_many users, UserView, "show.html", as: :data

  is roughly equivalent to:

      Enum.map(users, fn user ->
        render(UserView, "show.html", data: user)
      end)

  """
  def render_many(collection, view, template, assigns \\ %{}) do
    assigns = Map.new(assigns)
    resource_name = get_resource_name(assigns, view)

    Enum.map(collection, fn resource ->
      render(view, template, Map.put(assigns, resource_name, resource))
    end)
  end

  @doc """
  Renders a single item if not nil.

  The following:

      render_one user, UserView, "show.html"

  is roughly equivalent to:

      if user != nil do
        render(UserView, "show.html", user: user)
      end

  The underlying user is passed to the view and template as
  `:user`, which is inflected from the view name. The name
  of the key in assigns can be customized with the `:as` option:

      render_one user, UserView, "show.html", as: :data

  is roughly equivalent to:

      if user != nil do
        render(UserView, "show.html", data: user)
      end

  """
  def render_one(resource, view, template, assigns \\ %{})
  def render_one(nil, _view, _template, _assigns), do: nil

  def render_one(resource, view, template, assigns) do
    assigns = Map.new(assigns)
    render(view, template, assign_resource(assigns, view, resource))
  end

  @compile {:inline, [get_resource_name: 2]}

  defp get_resource_name(assigns, view) do
    case assigns do
      %{as: as} -> as
      _ -> view.__resource__
    end
  end

  defp assign_resource(assigns, view, resource) do
    Map.put(assigns, get_resource_name(assigns, view), resource)
  end

  @doc """
  Renders the template and returns iodata.
  """
  def render_to_iodata(module, template, assign) do
    render(module, template, assign) |> encode(template)
  end

  @doc """
  Renders the template and returns a string.
  """
  def render_to_string(module, template, assign) do
    render_to_iodata(module, template, assign) |> IO.iodata_to_binary()
  end

  defp encode(content, template) do
    if encoder = Template.format_encoder(template) do
      encoder.encode_to_iodata!(content)
    else
      content
    end
  end

  @doc false
  def __template_options__(module, opts) do
    if Module.get_attribute(module, :view_resource) do
      raise ArgumentError,
            "use Phoenix.View is being called twice in the module #{module}. " <>
              "Make sure to call it only once per module"
    else
      view_resource = String.to_atom(Phoenix.Template.resource_name(module, "View"))
      Module.put_attribute(module, :view_resource, view_resource)
    end

    root = opts[:root] || raise(ArgumentError, "expected :root to be given as an option")
    path = opts[:path]

    namespace =
      if given = opts[:namespace] do
        given
      else
        module
        |> Module.split()
        |> Enum.take(1)
        |> Module.concat()
      end

    root_path =
      Path.join(root, path || Template.module_to_template_root(module, namespace, "View"))

    [root: root_path] ++ Keyword.take(opts, [:pattern, :template_engines])
  end
end

Code.require_file("../fixtures/views.exs", __DIR__)

defmodule Phoenix.ViewTest do
  use ExUnit.Case, async: true

  doctest Phoenix.View
  import Phoenix.View

  ## local render

  test "converts assigns to maps even on local calls" do
    assert MyApp.UserView.render("edit.html", title: "Test") == "EDIT - Test"
  end

  ## render

  test "renders views defined on root" do
    assert render(MyApp.View, "show.html", message: "Hello world") ==
             {:safe, ["<div>Show! ", "Hello world", "</div>\n", "\n"]}
  end

  test "renders views without assigns" do
    assert MyApp.View.render(MyApp.UserView, "show.json") == %{foo: "bar"}
  end

  test "renders views keeping their template file info" do
    try do
      render(MyApp.View, "show.html", message: {:not, :a, :string})
    catch
      _, _ ->
        info = [file: ~c"test/fixtures/templates/show.html.eex", line: 1]
        assert {MyApp.View, :"show.html", 1, info} in __STACKTRACE__
    else
      _ ->
        flunk("expected rendering to raise")
    end
  end

  test "renders subviews with helpers" do
    assert render(MyApp.UserView, "index.html", title: "Hello world") ==
             {:safe, ["Hello world", "\n"]}

    assert render(MyApp.UserView, "show.json", []) ==
             %{foo: "bar"}
  end

  test "renders views even with deeply namespace module names" do
    assert render(MyApp.Nested.UserView, "show.json", []) ==
             %{foo: "bar"}

    assert render(MyApp.Templates.UserView, "show.json", []) ==
             %{foo: "bar"}
  end

  test "renders views with layouts" do
    html =
      render(MyApp.View, "show.html",
        title: "Test",
        message: "Hello world",
        layout: {MyApp.LayoutView, "app.html"}
      )

    assert html ==
             {:safe,
              [
                "<html>\n  <title>",
                "Test",
                "</title>\n  ",
                ["<div>Show! ", "Hello world", "</div>\n", "\n"],
                "\n</html>\n"
              ]}
  end

  test "validates explicitly passed layout" do
    assert_raise ArgumentError, fn ->
      render(MyApp.View, "show.html",
        title: "Test",
        message: "Hello world",
        layout: {"not a layout", "app.html"}
      )
    end
  end

  test "converts assigns to maps and removes :layout" do
    html =
      render_to_iodata(MyApp.UserView, "edit.html",
        title: "Test",
        layout: {MyApp.LayoutView, "app.html"}
      )

    assert html == ["<html>\n  <title>", "Test", "</title>\n  ", "EDIT - Test", "\n</html>\n"]
  end

  # render layout

  test "renders layout directly" do
    html =
      render_layout(MyApp.LayoutView, "app.html", title: "Test") do
        "Hello World"
      end

    assert html ==
             {:safe, ["<html>\n  <title>", "Test", "</title>\n  ", "Hello World", "\n</html>\n"]}
  end

  # render_to_*

  test "renders views to iodata/string using encoders" do
    assert render_to_iodata(MyApp.UserView, "index.html", title: "Hello world") ==
             ["Hello world", "\n"]

    assert render_to_iodata(MyApp.UserView, "show.json", []) ==
             ["{\"", [[], "foo"], "\":", [34, [], "bar", 34], 125]

    assert render_to_string(MyApp.UserView, "index.html", title: "Hello world") ==
             "Hello world\n"

    assert render_to_string(MyApp.UserView, "show.json", []) ==
             "{\"foo\":\"bar\"}"

    assert render_to_string(MyApp.UserView, "to_iodata.html", to_iodata: 123) ==
             "123"
  end

  test "renders views with layouts to iodata/string using encoders" do
    html =
      render_to_iodata(MyApp.View, "show.html",
        title: "Test",
        message: "Hello world",
        layout: {MyApp.LayoutView, "app.html"}
      )

    assert html ==
             [
               "<html>\n  <title>",
               "Test",
               "</title>\n  ",
               ["<div>Show! ", "Hello world", "</div>\n", "\n"],
               "\n</html>\n"
             ]

    html =
      render_to_string(MyApp.View, "show.html",
        title: "Test",
        message: "Hello world",
        layout: {MyApp.LayoutView, "app.html"}
      )

    assert html ==
             "<html>\n  <title>Test</title>\n  <div>Show! Hello world</div>\n\n\n</html>\n"

    html =
      render_to_string(MyApp.UserView, "to_iodata.html",
        title: "Test",
        message: "Hello world",
        to_iodata: 123,
        layout: {MyApp.LayoutView, "app.html"}
      )

    assert html ==
             "<html>\n  <title>Test</title>\n  123\n</html>\n"
  end

  ## render_many

  test "renders many with view" do
    user = %MyApp.User{}
    assert render_many([], MyApp.UserView, "show.text") == []

    assert render_many([user], MyApp.UserView, "show.text") ==
             ["show user: name"]

    assert render_many([user], MyApp.UserView, "show.text", prefix: "Dr. ") ==
             ["show user: Dr. name"]

    assert render_many([user], MyApp.UserView, "show.text", %{prefix: "Dr. "}) ==
             ["show user: Dr. name"]

    stream = Stream.concat([user], [%MyApp.Nested.User{}])

    assert render_many(stream, MyApp.UserView, "show.text") ==
             ["show user: name", "show user: nested name"]

    assert render_many(stream, MyApp.UserView, "show.text", prefix: "Dr. ") ==
             ["show user: Dr. name", "show user: Dr. nested name"]
  end

  test "renders many with view with custom as" do
    user = %MyApp.User{}
    assert render_many([user], MyApp.UserView, "data.text", as: :data) == ["show data: name"]
  end

  ## render_one

  test "renders one with view" do
    user = %MyApp.User{}
    assert render_one(nil, MyApp.UserView, "show.text") == nil

    assert render_one(user, MyApp.UserView, "show.text") ==
             "show user: name"

    assert render_one(user, MyApp.UserView, "show.text", prefix: "Dr. ") ==
             "show user: Dr. name"

    assert render_one(user, MyApp.UserView, "show.text", %{prefix: "Dr. "}) ==
             "show user: Dr. name"
  end

  test "renders one with view with custom as" do
    user = %MyApp.User{}
    assert render_one(user, MyApp.UserView, "data.text", as: :data) == "show data: name"
  end

  # render_existing

  test "renders_existing/3 renders template if it exists" do
    assert render_existing(MyApp.UserView, "index.html", title: "Test") ==
             {:safe, ["Test", "\n"]}
  end

  test "renders_existing/3 returns nil if template does not exist" do
    assert render_existing(MyApp.UserView, "not-exists", title: "Test") == nil
  end

  test "render_existing/3 renders explicitly defined functions" do
    assert render_existing(MyApp.UserView, "existing.html", []) ==
             "rendered existing"
  end

  # Misc.

  test "render_template can be called from overridden render/2" do
    assert render_to_string(MyApp.UserView, "render_template.html", name: "eric") ==
             "rendered template for ERIC\n"
  end

  test ":pattern can be used to customized precompiled patterns" do
    assert render_to_string(MyApp.UserView, "profiles/admin.html", []) == "admin profile\n"
  end

  test ":path can be provided custom root path" do
    assert render_to_string(MyApp.PathView, "path.html", []) == "path\n"
  end

  # Helpers

  test "template_path_to_name/2" do
    path = "/var/www/templates/admin/users/show.html.eex"
    root = "/var/www/templates"

    assert template_path_to_name(path, root) ==
             "admin/users/show.html"

    path = "/var/www/templates/users/show.html.eex"
    root = "/var/www/templates"

    assert template_path_to_name(path, root) ==
             "users/show.html"

    path = "/var/www/templates/home.html.eex"
    root = "/var/www/templates"

    assert template_path_to_name(path, root) ==
             "home.html"

    path = "/var/www/templates/home.html.haml"
    root = "/var/www/templates"

    assert template_path_to_name(path, root) ==
             "home.html"
  end

  ## On use

  defmodule View do
    use Phoenix.View, root: Path.join(__DIR__, "../fixtures"), path: "templates"

    def render(template, assigns) do
      render_template(template, assigns)
    end
  end

  test "render eex templates sanitizes against xss by default" do
    assert Phoenix.View.render_to_string(View, "show.html", %{message: ""}) ==
             "<div>Show! </div>\n\n"

    assert Phoenix.View.render_to_string(View, "show.html", %{
             message: "<script>alert('xss');</script>"
           }) ==
             "<div>Show! &lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;</div>\n\n"
  end

  test "render eex templates allows raw data to be injected" do
    assert View.render("safe.html", %{message: "<script>alert('xss');</script>"}) ==
             {:safe, ["Raw ", "<script>alert('xss');</script>", "\n"]}
  end

  test "compiles templates from path" do
    assert View.render("show.html", %{message: "hello!"}) ==
             {:safe, ["<div>Show! ", "hello!", "</div>\n", "\n"]}
  end

  test "adds catch-all render_template/2 that raises UndefinedError" do
    assert_raise Phoenix.Template.UndefinedError, ~r/Could not render "not-exists.html".*/, fn ->
      View.render("not-exists.html", %{})
    end
  end

  test "ignores missing template path" do
    defmodule OtherViews do
      use Phoenix.View, root: __DIR__, path: "not-exists"

      def render(template, assigns) do
        render_template(template, assigns)
      end

      def template_not_found(template, _assigns) do
        "Not found: #{template}"
      end
    end

    assert OtherViews.render("foo", %{}) == "Not found: foo"
  end

  test "template_not_found detects and short circuits infinite call-stacks" do
    defmodule InfiniteView do
      use Phoenix.View, root: __DIR__, path: "not-exists"

      def render(template, assigns) do
        render_template(template, assigns)
      end

      def template_not_found(_template, assigns) do
        render_template("this-does-not-exist.html", assigns)
      end
    end

    assert_raise Phoenix.Template.UndefinedError,
                 ~r/Could not render "this-does-not-exist.html".*/,
                 fn ->
                   InfiniteView.render("this-does-not-exist.html", %{})
                 end
  end

  test "generates __mix_recompile__? function" do
    refute View.__mix_recompile__?()
  end

  defmodule CustomEngineView do
    use Phoenix.View,
      root: Path.join(__DIR__, "../fixtures"),
      path: "templates",
      template_engines: %{
        foo: Phoenix.Template.EExEngine
      }

    def render(template, assigns) do
      render_template(template, assigns)
    end
  end

  test "custom view renders custom templates" do
    assert CustomEngineView.render("edit.html", %{message: "foo"}) ==
             {:safe, ["from ", "foo"]}
  end
end

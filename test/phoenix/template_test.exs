defmodule Phoenix.TemplateTest do
  use ExUnit.Case, async: true

  doctest Phoenix.Template
  require Phoenix.Template, as: Template

  @templates Path.expand("../fixtures/templates", __DIR__)

  test "engines/0" do
    assert is_map(Template.engines())
  end

  test "find_all/3 finds all templates in the given root" do
    templates = Template.find_all(@templates)
    assert Path.join(@templates, "show.html.eex") in templates

    templates = Template.find_all(Path.expand("unknown"))
    assert templates == []
  end

  test "hash/3 returns the hash for the given root" do
    assert is_binary(Template.hash(@templates))
  end

  test "format_encoder/1 returns the formatter for a given template" do
    assert Template.format_encoder("hello.html") == Phoenix.HTML.Engine
    assert Template.format_encoder("hello.js") == Phoenix.HTML.Engine
    assert Template.format_encoder("hello.unknown") == nil
  end

  describe "compile_all/4" do
    defmodule AllTemplates do
      Template.compile_all(
        &(&1 |> Path.basename() |> String.replace(".", "_")),
        Path.expand("../fixtures/templates", __DIR__)
      )
    end

    test "compiles all templates at once" do
      # TODO: Add trim tests once extracted
      assert AllTemplates.show_html_eex(%{message: "hello!"})
             |> Phoenix.HTML.safe_to_string() ==
               "<div>Show! hello!</div>\n\n"

      assert AllTemplates.show_html_eex(%{message: "<hello>"})
             |> Phoenix.HTML.safe_to_string() ==
               "<div>Show! &lt;hello&gt;</div>\n\n"

      assert AllTemplates.show_html_eex(%{message: {:safe, "<hello>"}})
             |> Phoenix.HTML.safe_to_string() ==
               "<div>Show! <hello></div>\n\n"

      assert AllTemplates.show_json_exs(%{}) == %{foo: "bar"}
      assert AllTemplates.show_text_eex(%{message: "hello"}) == "from hello"
      refute AllTemplates.__mix_recompile__?()
    end

    defmodule OptionsTemplates do
      Template.compile_all(
        &(&1 |> Path.basename() |> String.replace(".", "1")),
        Path.expand("../fixtures/templates", __DIR__),
        "*.html"
      )

      [{"show2json2exs", _}] =
        Template.compile_all(
          &(&1 |> Path.basename() |> String.replace(".", "2")),
          Path.expand("../fixtures/templates", __DIR__),
          "*.json"
        )

      [{"show3html3foo", _}] =
        Template.compile_all(
          &(&1 |> Path.basename() |> String.replace(".", "3")),
          Path.expand("../fixtures/templates", __DIR__),
          "*",
          %{foo: Phoenix.Template.EExEngine}
        )
    end

    test "compiles templates across several calls" do
      assert OptionsTemplates.show1html1eex(%{message: "hello!"})
             |> Phoenix.HTML.safe_to_string() ==
               "<div>Show! hello!</div>\n\n"

      assert OptionsTemplates.show2json2exs(%{}) == %{foo: "bar"}

      assert OptionsTemplates.show3html3foo(%{message: "hello"})
             |> Phoenix.HTML.safe_to_string() == "from hello"

      refute OptionsTemplates.__mix_recompile__?()
    end
  end
end

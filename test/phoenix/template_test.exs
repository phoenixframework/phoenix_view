defmodule Phoenix.TemplateTest do
  use ExUnit.Case, async: true

  doctest Phoenix.Template
  alias Phoenix.Template

  @templates Path.expand("../fixtures/templates", __DIR__)

  test "engines/0" do
    assert is_map(Template.engines())
  end

  test "find_all/1 finds all templates in the given root" do
    templates = Template.find_all(@templates)
    assert Path.join(@templates, "show.html.eex") in templates

    templates = Template.find_all(Path.expand("../ssl", @templates))
    assert templates == []
  end

  test "hash/1 returns the hash for the given root" do
    assert is_binary(Template.hash(@templates))
  end

  test "format_encoder/1 returns the formatter for a given template" do
    assert Template.format_encoder("hello.html") == Phoenix.HTML.Engine
    assert Template.format_encoder("hello.js") == Phoenix.HTML.Engine
    assert Template.format_encoder("hello.unknown") == nil
  end
end

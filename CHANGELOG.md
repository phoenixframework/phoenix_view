# CHANGELOG

## 2.0.0 (2022-10-26)

  * Extract `Phoenix.Template` to a separete dependency: `phoenix_template`
  * Document replacing `Phoenix.View` with `Phoenix.Component`
  * Deprecate `Phoenix.View.render_layout/4` in favor of `Phoenix.Component` with slots instead

## 1.1.2 (2022-02-02)

  * Fix dialyzer warnings on `template_not_found`

## 1.1.1 (2022-01-31)

  * Add compile-time dependencies to template engines

## 1.1.0 (2022-01-06)

  * Do not add compile time dependencies on arguments given to Phoenix.View and Phoenix.Template
  * Soft-deprecate `render_existing/3` in favor of `function_exported?/3` checks

## 1.0.0 (2021-07-18)

  * Initial release

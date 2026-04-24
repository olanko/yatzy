defmodule YatzyWeb.ErrorJSONTest do
  use YatzyWeb.ConnCase, async: true

  test "renders 404" do
    assert YatzyWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert YatzyWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end

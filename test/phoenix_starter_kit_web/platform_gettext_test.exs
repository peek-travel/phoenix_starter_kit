defmodule PhoenixStarterKitWeb.PlatformGettextTest do
  use ExUnit.Case, async: false

  alias PhoenixStarterKitWeb.PlatformGettext

  describe "put_platform/1 and get_platform/0" do
    test "stores and retrieves platform from process dictionary" do
      PlatformGettext.put_platform(:acme)
      assert PlatformGettext.get_platform() == :acme
    end

    test "returns :default when no platform is set" do
      Process.delete({PlatformGettext, :platform})
      assert PlatformGettext.get_platform() == :default
    end
  end

  describe "t/1" do
    test "uses platform from process dictionary" do
      PlatformGettext.put_platform(:acme)
      # acme.po has "common.save" -> "Submit"
      assert PlatformGettext.t("common.save") == "Submit"
    end

    test "falls back to default domain when platform has no override" do
      PlatformGettext.put_platform(:peek)
      # peek has no .po file, falls back to default.po
      assert PlatformGettext.t("common.save") == "Save"
    end

    test "uses default platform when none set" do
      Process.delete({PlatformGettext, :platform})
      assert PlatformGettext.t("common.cancel") == "Cancel"
    end

    test "normalizes peek_pro to peek domain" do
      PlatformGettext.put_platform(:peek_pro)
      # peek_pro should use peek domain (no override), falls back to default
      assert PlatformGettext.t("common.cancel") == "Cancel"
    end

    test "returns key when no translation exists in any domain" do
      PlatformGettext.put_platform(:acme)
      assert PlatformGettext.t("unknown.key") == "unknown.key"
    end
  end

  describe "t/2 with bindings" do
    test "uses platform from process dictionary with bindings" do
      PlatformGettext.put_platform(:acme)
      # acme.po has "flash.saved_successfully" -> "Event saved successfully"
      assert PlatformGettext.t("flash.saved_successfully", []) == "Event saved successfully"
    end

    test "falls back to default domain with bindings when platform has no override" do
      PlatformGettext.put_platform(:peek)
      assert PlatformGettext.t("flash.saved_successfully", []) == "Saved successfully"
    end

    test "normalizes peek_pro to peek domain with bindings" do
      PlatformGettext.put_platform(:peek_pro)
      assert PlatformGettext.t("flash.saved_successfully", []) == "Saved successfully"
    end

    test "returns key with bindings when no translation exists" do
      PlatformGettext.put_platform(:peek)
      result = PlatformGettext.t("unknown.key.%{value}", value: "thing")
      assert result == "unknown.key.thing"
    end
  end
end

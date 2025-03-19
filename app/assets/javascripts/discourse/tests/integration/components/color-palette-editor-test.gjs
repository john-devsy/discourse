import { click, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ColorPaletteEditor from "admin/components/color-palette-editor";
import ColorSchemeColor from "admin/models/color-scheme-color";

function editor() {
  return {
    isActiveModeLight() {
      return this.lightModeNavPill().classList.contains("active");
    },

    isActiveModeDark() {
      return this.darkModeNavPill().classList.contains("active");
    },

    lightModeNavPill() {
      return this.navPills().querySelector(".light-tab");
    },

    darkModeNavPill() {
      return this.navPills().querySelector(".dark-tab");
    },

    navPills() {
      return find(".color-palette-editor__nav-pills");
    },

    async switchToLightTab() {
      await click(this.lightModeNavPill());
    },

    async switchToDarkTab() {
      await click(this.darkModeNavPill());
    },

    color(name) {
      return {
        container() {
          return find(
            `.color-palette-editor__colors-item[data-color-name="${name}"]`
          );
        },

        displayName() {
          return this.container()
            .querySelector(".color-palette-editor__color-name")
            .textContent.trim();
        },

        description() {
          return this.container()
            .querySelector(".color-palette-editor__color-description")
            .textContent.trim();
        },

        colorInput() {
          return this.container().querySelector(".color-palette-editor__input");
        },

        textInput() {
          return this.container().querySelector(
            ".color-palette-editor__text-input"
          );
        },

        async sendColorInputEvent(value) {
          const input = this.colorInput();
          input.value = value;
          await triggerEvent(input, "input");
        },

        async sendColorChangeEvent(value) {
          const input = this.colorInput();
          input.value = value;
          await triggerEvent(input, "change");
        },

        async sendTextChangeEvent(value) {
          const input = this.textInput();
          input.value = value;
          await triggerEvent(input, "change");
        },
      };
    },
  };
}

module("Integration | Component | ColorPaletteEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.subject = editor();
  });

  test("switching between light and dark modes", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
        dark_hex: "1e3c8a",
      },
      {
        name: "header_background",
        hex: "473921",
        dark_hex: "f2cca9",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    assert.true(
      this.subject.isActiveModeLight(),
      "light mode tab is active by default"
    );
    assert.false(
      this.subject.isActiveModeDark(),
      "dark mode tab is not active by default"
    );

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#aaaaaa",
      "input for the primary color is showing the light color"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "aaaaaa",
      "text input value for the primary color is showing the light color"
    );

    assert.strictEqual(
      this.subject.color("header_background").colorInput().value,
      "#473921",
      "input for the header_background color is showing the light color"
    );
    assert.strictEqual(
      this.subject.color("header_background").textInput().value,
      "473921",
      "text input value for the header_background color is showing the light color"
    );

    await this.subject.switchToDarkTab();

    assert.false(
      this.subject.isActiveModeLight(),
      "light mode tab is now inactive"
    );
    assert.true(this.subject.isActiveModeDark(), "dark mode tab is now active");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#1e3c8a",
      "input for the primary color is showing the dark color"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "1e3c8a",
      "text input value for the primary color is showing the dark color"
    );

    assert.strictEqual(
      this.subject.color("header_background").colorInput().value,
      "#f2cca9",
      "input for the header_background color is showing the dark color"
    );
    assert.strictEqual(
      this.subject.color("header_background").textInput().value,
      "f2cca9",
      "text input value for the header_background color is showing the dark color"
    );
  });

  test("uses the i18n string for the color name", async function (assert) {
    const colors = [
      {
        name: "header_background",
        hex: "473921",
        dark_hex: "f2cca9",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    assert.strictEqual(
      this.subject.color("header_background").displayName(),
      "header background"
    );
  });

  test("modifying colors", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
        dark_hex: "1e3c8a",
      },
      {
        name: "header_background",
        hex: "473921",
        dark_hex: "f2cca9",
      },
    ].map((data) => ColorSchemeColor.create(data));

    const lightChanges = [];
    const darkChanges = [];

    const onLightColorChange = (name, value) => {
      lightChanges.push([name, value]);
    };
    const onDarkColorChange = (name, value) => {
      darkChanges.push([name, value]);
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onLightColorChange={{onLightColorChange}}
          @onDarkColorChange={{onDarkColorChange}}
        />
      </template>
    );

    await this.subject.color("primary").sendColorInputEvent("#abcdef");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#abcdef",
      "the input element for the primary color changes its value for `input` events"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "abcdef",
      "text input value for the primary color updates for `input` events"
    );
    assert.strictEqual(
      lightChanges.length,
      0,
      "light color change callbacks aren't triggered for `input` events"
    );
    assert.strictEqual(
      darkChanges.length,
      0,
      "dark color change callbacks aren't triggered for `input` events"
    );

    await this.subject.color("primary").sendColorChangeEvent("#fedcba");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#fedcba",
      "the input element for the primary color changes its value for `change` events"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "fedcba",
      "text input value for the primary color updates for `change` events"
    );
    assert.deepEqual(
      lightChanges,
      [["primary", "fedcba"]],
      "light color change callbacks are triggered for `change` eventswhen the light color changes"
    );

    assert.strictEqual(
      darkChanges.length,
      0,
      "dark color change callbacks aren't triggered for `change` events when the light color changes"
    );

    await this.subject.switchToDarkTab();

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#1e3c8a",
      "the dark color isn't affected by the change to the light color"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "1e3c8a",
      "the dark color isn't affected by the change to the light color"
    );

    lightChanges.length = 0;
    darkChanges.length = 0;

    await this.subject
      .color("header_background")
      .sendColorInputEvent("#776655");

    assert.strictEqual(
      this.subject.color("header_background").colorInput().value,
      "#776655",
      "the input element for the header_background color changes its value for `input` events"
    );
    assert.strictEqual(
      this.subject.color("header_background").textInput().value,
      "776655",
      "text input value for the header_background color updates for `input` events"
    );
    assert.strictEqual(
      lightChanges.length,
      0,
      "light color change callbacks aren't triggered for `input` events"
    );
    assert.strictEqual(
      darkChanges.length,
      0,
      "dark color change callbacks aren't triggered for `input` events"
    );

    await this.subject
      .color("header_background")
      .sendColorChangeEvent("#99aaff");

    assert.strictEqual(
      this.subject.color("header_background").colorInput().value,
      "#99aaff",
      "the input element for the header_background color changes its value for `change` events"
    );
    assert.strictEqual(
      this.subject.color("header_background").textInput().value,
      "99aaff",
      "text input value for the header_background color updates for `change` events"
    );
    assert.deepEqual(
      darkChanges,
      [["header_background", "99aaff"]],
      "dark color change callbacks are triggered for `change` eventswhen the dark color changes"
    );

    assert.strictEqual(
      lightChanges.length,
      0,
      "light color change callbacks aren't triggered for `change` events when the dark color changes"
    );

    await this.subject.switchToLightTab();

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#fedcba",
      "the light color for the primary color is remembered after switching tabs"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "fedcba",
      "the light color for the primary color is remembered after switching tabs"
    );

    assert.strictEqual(
      this.subject.color("header_background").colorInput().value,
      "#473921",
      "the light color for the header_background color remains unchanged"
    );
    assert.strictEqual(
      this.subject.color("header_background").textInput().value,
      "473921",
      "the light color for the header_background color remains unchanged"
    );

    await this.subject.switchToDarkTab();

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#1e3c8a",
      "the dark color for the primary color remains unchanged"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "1e3c8a",
      "the dark color for the primary color remains unchanged"
    );

    assert.strictEqual(
      this.subject.color("header_background").colorInput().value,
      "#99aaff",
      "the dark color for the header_background color is remembered after switching tabs"
    );
    assert.strictEqual(
      this.subject.color("header_background").textInput().value,
      "99aaff",
      "the dark color for the header_background color is remembered after switching tabs"
    );
  });

  test("changing the text input field updates the color picker", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
        dark_hex: "1e3c8a",
      },
    ].map((data) => ColorSchemeColor.create(data));

    const lightChanges = [];
    const darkChanges = [];

    const onLightColorChange = (name, value) => {
      lightChanges.push([name, value]);
    };
    const onDarkColorChange = (name, value) => {
      darkChanges.push([name, value]);
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onLightColorChange={{onLightColorChange}}
          @onDarkColorChange={{onDarkColorChange}}
        />
      </template>
    );

    await this.subject.color("primary").sendTextChangeEvent("9999cc");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#9999cc",
      "the color input reflects the text input"
    );
    assert.deepEqual(
      lightChanges,
      [["primary", "9999cc"]],
      "light color change callbacks are triggered for `change` events when the light color changes"
    );

    assert.strictEqual(
      darkChanges.length,
      0,
      "no changes to dark mode colors are mode"
    );

    lightChanges.length = 0;

    await this.subject.switchToDarkTab();

    await this.subject.color("primary").sendTextChangeEvent("1f9c3e");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#1f9c3e",
      "the color input reflects the text input"
    );
    assert.deepEqual(
      darkChanges,
      [["primary", "1f9c3e"]],
      "dark color change callbacks are triggered for `change` events when the light color changes"
    );
    assert.strictEqual(
      lightChanges.length,
      0,
      "no changes to light mode colors are mode"
    );
  });

  test("converting 3 digits hex values to 6 digits", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "a8c",
        dark_hex: "971",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#aa88cc",
      "the input field has the equivalent 6 digits value"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "aa88cc",
      "the text input value shows the 6 digits format"
    );

    await this.subject.switchToDarkTab();

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#997711",
      "the input field has the equivalent 6 digits value"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "997711",
      "the text input value shows the 6 digits format"
    );
  });
});

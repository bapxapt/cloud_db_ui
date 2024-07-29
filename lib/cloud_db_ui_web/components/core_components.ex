defmodule CloudDbUiWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com).
  See `icon/1` for usage.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.{JS, Rendered}

  import CloudDbUiWeb.Gettext
  import Phoenix.HTML.Tag

  @type transition() :: {String.t(), String.t(), String.t()}
  @type error() :: CloudDbUi.Type.error()
  @type errors() :: CloudDbUi.Type.errors()

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :inner_block_id, :string, default: nil
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  slot :inner_block, required: true

  @spec modal(%{atom() => any()}) :: %Rendered{}
  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-green-100/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={js_exec_data_cancel(@id, @inner_block_id)}
              phx-key="escape"
              phx-click-away={js_exec_data_cancel(@id, @inner_block_id)}
              class={[
                "shadow-zinc-700/10 ring-zinc-700/10 relative hidden",
                "rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
              ]}
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={js_exec_data_cancel(@id, @inner_block_id)}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional ID of a flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  @spec flash(%{atom() => any()}) :: %Rendered{}
  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-8 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        flash_kind_class(@kind)
      ]}
      {@rest}
    >
      <p
        :if={@title}
        class="flex items-center gap-1.5 text-sm font-semibold leading-6"
      >
        <.icon
          :if={@kind in [:info, :error]}
          name={flash_title_icon_name(@kind)}
          class="h-4 w-4"
        />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button
        type="button"
        class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}
      >
        <.icon
          name="hero-x-mark-solid"
          class="h-5 w-5 opacity-40 group-hover:opacity-70"
        />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional ID of a flash container"

  @spec flash_group(%{atom() => any()}) :: %Rendered{}
  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        Hang in there while we get back on track
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="E-mail"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :margin_classes, :string, default: "mt-10 space-y-8"
  attr :bg_class, :string, default: "bg-white"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  @spec simple_form(%{atom() => any()}) :: %Rendered{}
  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <%= content_tag(:div, [class: class([@margin_classes, @bg_class])]) do %>
        <%= render_slot(@inner_block, f) %>
        <div
          :for={action <- @actions}
          class="mt-2 flex items-center justify-between gap-6"
        >
          <%= render_slot(action, f) %>
        </div>
      <% end %>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  @spec button(%{atom() => any()}) :: %Rendered{}
  def button(assigns) do
    ~H"""
    <button type={@type} class={button_class() ++ [@class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :margin_class, :string, default: "mt-2"

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :root_div_style, :string, default: nil, doc: "inline styling for the root `<div>`"

  attr :errors_on_mount, :boolean,
    default: false,
    doc: "display errors right after the page loads"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  @spec input(%{atom() => any()}) :: %Rendered{}
  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(
      :name,
      fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end
    )
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <%= content_tag(:div, input_root_div_attrs(@name, @root_div_style)) do %>
      <label
        id={if @id, do: @id <> "-label"}
        class="flex items-center gap-4 text-sm leading-6 text-zinc-600"
      >
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors} show_on_mount={@errors_on_mount}>
        <%= msg %>
      </.error>
    <% end %>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <%= content_tag(:div, input_root_div_attrs(@name, @root_div_style)) do %>
      <.label id={if @id, do: @id <> "-label"} for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          class([@margin_class, "block w-full rounded-md border"]),
          "border-gray-300 bg-white shadow-sm",
          "focus:border-zinc-400 focus:ring-0 sm:text-sm"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors} show_on_mount={@errors_on_mount}>
        <%= msg %>
      </.error>
    <% end %>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <%= content_tag(:div, input_root_div_attrs(@name, @root_div_style)) do %>
      <.label id={if @id, do: @id <> "-label"} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          class([@margin_class, "block w-full rounded-lg text-zinc-900"]),
          "focus:ring-0 sm:text-sm sm:leading-6 min-h-[6rem]",
          text_input_phx_no_feedback_class(@errors_on_mount),
          text_input_border_class(@errors)
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors} show_on_mount={@errors_on_mount}>
        <%= msg %>
      </.error>
    <% end %>
    """
  end

  # All other inputs: `text`, `datetime-local`, `url`, `password`, etc. —
  # are handled here.
  def input(assigns) do
    ~H"""
    <%= content_tag(:div, input_root_div_attrs(@name, @root_div_style)) do %>
      <.label id={if @id, do: @id <> "-label"} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          class([@margin_class, "block w-full rounded-lg text-zinc-900"]),
          "focus:ring-0 sm:text-sm sm:leading-6",
          text_input_phx_no_feedback_class(@errors_on_mount),
          text_input_border_class(@errors)
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors} show_on_mount={@errors_on_mount}>
        <%= msg %>
      </.error>
    <% end %>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :id, :string, default: nil

  slot :inner_block, required: true

  @spec label(%{atom() => any()}) :: %Rendered{}
  def label(assigns) do
    ~H"""
    <label
      id={@id}
      for={@for}
      class="block text-sm font-semibold leading-6 text-zinc-800"
    >
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  attr :show_on_mount, :boolean, default: false

  slot :inner_block, required: true

  @spec error(%{atom() => any()}) :: %Rendered{}
  def error(assigns) do
    ~H"""
    <p
      class={[
        "mt-3 flex gap-3 text-sm leading-6 text-rose-600",
        !@show_on_mount && "phx-no-feedback:hidden"
      ]}
    >
      <.icon
        name="hero-exclamation-circle-mini"
        class="mt-0.5 h-5 w-5 flex-none"
      />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  # `:rest` instead of `:class` to avoid `class=""` with a `nil` `:class`.
  attr :rest, :global, doc: "arbitrary HTML attributes to add to a header"

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  # TODO: would use <%= content_tag(:header, [class: @class]) do %>,
    # TODO: but it does not have data-phx-id="m15-phx-GAt-0jCEWIiG6QEB"

  @spec header(%{atom() => any()}) :: %Rendered{}
  def header(assigns) do
    assigns =
      Map.update!(assigns, :rest, &Map.put(&1, :class, header_class(assigns)))

    ~H"""
    <header {@rest}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="flex-none">
        <%= render_slot_trimmed(@__changed__, @actions) %>
      </div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :col_extra_classes, :map, default: %{},
    doc: "extra classes for each column (column indices begin with 0)"

  attr :row_item, :any, default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  @spec table(%{atom() => any()}) :: %Rendered{}
  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal">
              <%= col[:label] %>
            </th>
            <th :if={@action != []} class="relative p-0 pb-4">
              <span class="sr-only"><%= gettext("Actions") %></span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class={[
            "relative divide-y divide-zinc-100 border-t border-zinc-200",
            "text-sm leading-6 text-zinc-700"
          ]}
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="group hover:bg-zinc-50"
          >
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                class([@col_extra_classes[i], "relative p-0"]),
                @row_click && "hover:cursor-pointer"
              ]}
            >
              <div class="block py-4 pr-6">
                <span
                  class={[
                    "absolute -inset-y-px right-0 -left-4",
                    "group-hover:bg-zinc-50 sm:rounded-l-xl"
                  ]}
                />
                <span
                  class={class(["relative", i == 0 && "font-semibold text-zinc-900"])}
                >
                  <%= render_slot(col, @row_item.(row)) %>
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div
                class={[
                  "relative whitespace-nowrap py-4 text-right text-sm",
                  "font-medium flex items-center"
                ]}
              >
                <span
                  class={[
                    "absolute -inset-y-px -right-4 left-0",
                    "group-hover:bg-zinc-50 sm:rounded-r-xl"
                  ]}
                />
                <span
                  :for={action <- @action}
                  class={[
                    "relative ml-4 font-semibold leading-6 text-zinc-900",
                    "hover:text-zinc-700"
                  ]}
                >
                  <%= render_slot(action, @row_item.(row)) %>
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  attr :width_class, :string, default: "w-1/4"

  attr :title_text_class, :string, default: "text-zinc-500"

  slot :item, required: true do
    attr :title, :string, required: true
  end

  @spec list(%{atom() => any()}) :: %Rendered{}
  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div
          :for={item <- @item}
          class="flex gap-4 py-4 text-sm leading-6 sm:gap-8"
        >
          <dt class={class([@width_class, "flex-none", @title_text_class])}>
            <%= item.title %>
          </dt>
          <dd class="text-zinc-700"><%= render_slot(item) %></dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  @spec back(%{atom() => any()}) :: %Rendered{}
  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class={[
          "text-sm font-semibold leading-6 text-zinc-900",
          "hover:text-zinc-700"
        ]}
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        <%= render_slot(@inner_block) %>
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  @spec icon(%{atom() => any()}) :: %Rendered{}
  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  @spec show(%JS{}, String.t()) :: %JS{}
  def show(js \\ %JS{}, selector) do
    JS.show(js, [to: selector, transition: transition_show()])
  end

  @spec hide(%JS{}, String.t()) :: %JS{}
  def hide(js \\ %JS{}, selector) do
    JS.hide(js, [to: selector, transition: transition_hide()])
  end

  @spec show_modal(%JS{}, String.t()) :: %JS{}
  def show_modal(js \\ %JS{}, id) do
    js
    |> JS.show([to: "##{id}"])
    |> JS.show([to: "##{id}-bg", transition: transition_show()])
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", [to: "body"])
    |> JS.focus_first(to: "##{id}-content")
  end

  @spec hide_modal(%JS{}, String.t()) :: %JS{}
  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide([to: "##{id}-bg", transition: transition_hide()])
    |> hide("##{id}-container")
    |> JS.hide([to: "##{id}", transition: {"block", "block", "hidden"}])
    |> JS.remove_class("overflow-hidden", [to: "body"])
    |> JS.pop_focus()
  end

  @doc """
  Translate an error message using gettext.
  """
  @spec translate_error(error()) :: binary()
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(CloudDbUiWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(CloudDbUiWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translate the errors for a field from a keyword list of errors.
  """
  @spec translate_errors(errors(), atom()) :: [binary()]
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  A base button class to be used with `<.link>`.
  """
  @spec button_class() :: [String.t()]
  def button_class() do
    [
      "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900",
      "hover:bg-zinc-700 py-2 px-3",
      "text-sm font-semibold leading-6 text-white active:text-white/80"
    ]
  end

  # The `class=""` value for `<.header>`.
  @spec header_class(%{atom() => any()}) :: String.t() | nil
  defp header_class(%{actions: acts, rest: rest} = _assigns) do
    class([
      acts != [] && "flex items-center justify-between gap-6",
      rest[:class]
    ])
  end

  # An additional, kind-specific part of the `class=""` value
  # for `<.flash>`.
  @spec flash_kind_class(atom()) :: String.t() | nil
  defp flash_kind_class(:info) do
    "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900"
  end

  defp flash_kind_class(:error) do
    "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
  end

  defp flash_kind_class(_kind), do: nil

  @spec text_input_phx_no_feedback_class(boolean()) :: String.t() | nil
  defp text_input_phx_no_feedback_class(false = _errors_on_mount?) do
    "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400"
  end

  defp text_input_phx_no_feedback_class(true = _errors_on_mount?), do: nil

  defp text_input_border_class([]), do: "border-zinc-300 focus:border-zinc-400"

  defp text_input_border_class(_), do: "border-rose-400 focus:border-rose-400"

  # Join `classes` into a `class=` attribute value.
  @spec class([String.t()]) :: String.t() | nil
  defp class(classes) do
    classes
    |> Enum.reject(&(&1 in [nil, "", true, false]))
    |> case do
      [] -> nil
      non_empty -> Enum.join(non_empty, " ")
    end
  end

  # Prevent whitespaces between children of `div.flex-none`.
  @spec render_slot_trimmed(%{atom() => any()} | nil, [%{atom() => any()}]) ::
          %Rendered{}
  defp render_slot_trimmed(changed, slot) do
    changed
    |> Phoenix.Component.__render_slot__(slot, nil)
    |> case do
      %{static: static} = rendered ->
        static_new =
          static
          |> Enum.with_index()
          |> Enum.map(fn {element, index} ->
            case index == 0 or index == length(static) - 1 do
              false -> String.replace(element, ~r/^\s*/, "")
              true -> element
            end
          end)

        Map.replace!(rendered, :static, static_new)

      any ->
        any
    end
  end

  @spec flash_title_icon_name(atom()) :: String.t()
  defp flash_title_icon_name(:info), do: "hero-information-circle-mini"

  defp flash_title_icon_name(:error), do: "hero-exclamation-circle-mini"

  # Attributes for a `content_tag()` that allows to prevent `style=""`
  # when `style` is `nil`.
  @spec input_root_div_attrs(any(), String.t()) :: keyword()
  defp input_root_div_attrs(name, style) do
    [phx_feedback_for: name, style: style]
  end

  @spec js_exec_data_cancel(String.t(), String.t() | nil) :: %JS{}
  defp js_exec_data_cancel(id, inner_block_id) do
    "data-cancel"
    |> JS.exec([to: "##{id}"])
    |> js_hide_all_flash_kinds()
    |> maybe_js_push_cancel_modal_flash_timer(inner_block_id)
  end

  # Immediately hide all `"#flash-#{kind}"` elements (`:time` defaults
  # to 200, but no `:transition`).
  @spec js_hide_all_flash_kinds(%JS{}) :: %JS{}
  defp js_hide_all_flash_kinds(js) do
    [:error, :info]
    |> Enum.reduce(js, fn kind, acc ->
      JS.hide(acc, [to: "#flash-#{kind}"])
    end)
  end

  @spec maybe_js_push_cancel_modal_flash_timer(%JS{}, String.t() | nil) ::
          %JS{}
  defp maybe_js_push_cancel_modal_flash_timer(js, nil = _inner_bl_id), do: js

  defp maybe_js_push_cancel_modal_flash_timer(js, inner_block_id) do
    JS.push(js, "cancel_modal_flash_timer", [target: "##{inner_block_id}"])
  end

  @spec transition_show(String.t(), non_neg_integer()) :: transition()
  defp transition_show(timing \\ "ease-out", duration \\ 300) do
    {
      "transition-all transform #{timing} duration-#{duration}",
      "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
      "opacity-100 translate-y-0 sm:scale-100"
    }
  end

  @spec transition_hide(String.t(), non_neg_integer()) :: transition()
  defp transition_hide(timing \\ "ease-in", duration \\ 200) do
    {
      "transition-all transform #{timing} duration-#{duration}",
      "opacity-100 translate-y-0 sm:scale-100",
      "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
    }
  end
end

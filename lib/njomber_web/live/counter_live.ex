defmodule NjomberWeb.CounterLive do
  use NjomberWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream(:counters, [])
      |> assign(:form, to_form(%{"name" => ""}, as: :counter))
      |> assign(:loading, false)
      |> assign(:counters_empty?, true)

    {:ok, socket}
  end

  def handle_event("validate", %{"counter" => counter_params}, socket) do
    form = to_form(counter_params, as: :counter)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("create_counter", %{"counter" => %{"name" => name}}, socket) do
    if String.trim(name) == "" do
      {:noreply, socket}
    else
      # In the future, this will call your blockchain library
      # For now, create a mock counter with a temporary ID
      new_counter = %{
        id: "counter_#{System.unique_integer([:positive])}",
        name: String.trim(name),
        value: 0,
        created_at: DateTime.utc_now(),
        tx_hash: "0x" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
      }

      socket =
        socket
        |> stream_insert(:counters, new_counter, at: 0)
        |> assign(:form, to_form(%{"name" => ""}, as: :counter))
        |> assign(:counters_empty?, false)
        |> put_flash(:info, "Counter '#{name}' created on blockchain!")

      {:noreply, socket}
    end
  end

  def handle_event("increment_counter", %{"counter_id" => counter_id}, socket) do
    # Find the counter in the stream to update it
    # Note: In a real app, you'd get the updated counter from your blockchain service
    updated_counter = %{
      id: counter_id,
      # Mock name
      name: "Counter #{String.replace(counter_id, "counter_", "")}",
      # In real app, get current value + 1 from blockchain
      value: 1,
      created_at: DateTime.utc_now(),
      tx_hash: "0x" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    }

    socket =
      socket
      |> assign(:loading, true)
      |> stream_insert(:counters, updated_counter)
      |> assign(:loading, false)
      |> put_flash(:info, "Counter incremented on blockchain!")

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-gray-900 mb-2">
              Blockchain Counter Demo
            </h1>
            <p class="text-lg text-gray-600">
              Create and increment counters stored on the blockchain
            </p>
          </div>
          
    <!-- Create Counter Form -->
          <div class="bg-white rounded-xl shadow-lg p-6 mb-8">
            <h2 class="text-xl font-semibold text-gray-800 mb-4">
              Create New Counter
            </h2>

            <.form
              for={@form}
              id="counter-form"
              phx-change="validate"
              phx-submit="create_counter"
              class="flex gap-4"
            >
              <div class="flex-1">
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="Enter counter name..."
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
              <button
                type="submit"
                class={[
                  "px-6 py-2 bg-blue-600 text-white rounded-lg font-medium transition-colors",
                  "hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
                  @form[:name].value == "" && "opacity-50 cursor-not-allowed"
                ]}
                disabled={@form[:name].value == ""}
              >
                <.icon name="hero-plus" class="w-5 h-5 inline mr-1" /> Create Counter
              </button>
            </.form>
          </div>
          
    <!-- Counters List -->
          <div class="space-y-4">
            <div id="counters" phx-update="stream">
              <%= if @counters_empty? do %>
                <div class="bg-white rounded-xl shadow-lg p-8 text-center">
                  <.icon name="hero-cube" class="w-16 h-16 text-gray-400 mx-auto mb-4" />
                  <h3 class="text-lg font-medium text-gray-900 mb-2">
                    No counters yet
                  </h3>
                  <p class="text-gray-600">
                    Create your first blockchain counter above!
                  </p>
                </div>
              <% end %>

              <div :for={{id, counter} <- @streams.counters} id={id} class="counter-card">
                <div class="bg-white rounded-xl shadow-lg p-6 hover:shadow-xl transition-shadow">
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <h3 class="text-xl font-semibold text-gray-800 mb-1">
                        {counter.name}
                      </h3>
                      <div class="text-sm text-gray-500 space-y-1">
                        <p>
                          <span class="font-medium">Created:</span>
                          {Calendar.strftime(counter.created_at, "%B %d, %Y at %I:%M %p")}
                        </p>
                        <p class="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                          TX: {String.slice(counter.tx_hash, 0, 10)}...
                        </p>
                      </div>
                    </div>

                    <div class="text-center ml-6">
                      <div class="text-5xl font-bold text-blue-600 mb-2">
                        {counter.value}
                      </div>
                      <button
                        phx-click="increment_counter"
                        phx-value-counter_id={counter.id}
                        class={[
                          "px-4 py-2 bg-green-600 text-white rounded-lg font-medium transition-all",
                          "hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2",
                          "active:scale-95",
                          @loading && "opacity-50 cursor-not-allowed"
                        ]}
                        disabled={@loading}
                      >
                        <.icon name="hero-plus" class="w-4 h-4 inline mr-1" /> Increment
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

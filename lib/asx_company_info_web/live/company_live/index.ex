defmodule AsxCompanyInfoWeb.CompanyLive.Index do
  use AsxCompanyInfoWeb, :live_view

  alias AsxCompanyInfo.MarketData

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> assign(:company_data, nil)
     |> assign(:quote_data, nil)
     |> assign(:current_ticker, "")
     |> assign(:form, to_form(%{"ticker" => ""}))}
  end

  @impl true
  def handle_event("search", %{"ticker" => ticker}, socket) do
    normalized_ticker =
      ticker
      |> String.trim()
      |> String.upcase()

    case validate_ticker(normalized_ticker) do
      :ok ->
        send(self(), {:fetch_data, normalized_ticker})

        {:noreply,
         socket
         |> assign(:loading, true)
         |> assign(:error, nil)
         |> assign(:current_ticker, normalized_ticker)
         |> assign(:form, to_form(%{"ticker" => normalized_ticker}))}

      {:error, error_message} ->
        {:noreply, assign(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("select_popular", %{"ticker" => ticker}, socket) do
    send(self(), {:fetch_data, ticker})

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:current_ticker, ticker)
     |> assign(:form, to_form(%{"ticker" => ticker}))}
  end

  @impl true
  def handle_info({:fetch_data, ticker}, socket) do
    # Fetch both company info and quote data in parallel
    tasks = [
      Task.async(fn -> MarketData.fetch_company_info(ticker) end),
      Task.async(fn -> MarketData.fetch_quote(ticker) end)
    ]

    results = Task.await_many(tasks, :timer.seconds(10))

    case results do
      [{:ok, company_data}, {:ok, quote_data}] ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:company_data, company_data)
         |> assign(:quote_data, quote_data)
         |> assign(:error, nil)}

      [{:error, reason}, _] ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, format_error(reason, ticker))}

      [_, {:error, reason}] ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, format_error(reason, ticker))}
    end
  end

  defp validate_ticker(ticker) do
    cond do
      String.length(ticker) < 3 ->
        {:error, "Ticker must be at least 3 characters"}

      !Regex.match?(~r/^[A-Z0-9]+$/, ticker) ->
        {:error, "Ticker must contain only letters and numbers"}

      true ->
        :ok
    end
  end

  defp format_error(:not_found, ticker) do
    "Ticker '#{ticker}' not found or may be delisted"
  end

  defp format_error(:bad_request, _ticker) do
    "Invalid request. Please check the ticker symbol"
  end

  defp format_error(_reason, _ticker) do
    "Failed to fetch company information. Please try again later"
  end

  # Component functions
  def search_form(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-submit="search"
      class={[
        "bg-white rounded-lg border border-[#e9ecef] p-6 shadow-sm",
        Map.get(assigns, :centered) && "w-full max-w-md"
      ]}
    >
      <div class="space-y-4">
        <!-- Search Input -->
        <div>
          <label class="block text-sm font-medium text-[#212529] mb-2">
            Search ASX Ticker
          </label>
          <div class="flex gap-2">
            <div class="flex-1 relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-[#6c757d] font-medium">
                ASX:
              </span>
              <input
                type="text"
                name="ticker"
                value={@current_ticker}
                placeholder="e.g., CBA"
                class="w-full pl-16 pr-4 py-2 border border-[#e9ecef] rounded-md focus:outline-none focus:ring-2 focus:ring-[#20705c] focus:border-transparent uppercase placeholder:text-[#6c757d]/60 text-[#212529]"
                phx-debounce="300"
              />
            </div>
            <button
              type="submit"
              class="px-6 py-2 bg-[#20705c] text-white rounded-md hover:bg-[#1a5c4d] focus:outline-none focus:ring-2 focus:ring-[#20705c] focus:ring-offset-2 transition-colors"
            >
              Search
            </button>
          </div>
        </div>

        <!-- Popular Stocks -->
        <div>
          <p class="text-sm text-[#6c757d] mb-2">Popular stocks:</p>
          <div class="flex gap-2">
            <%= for ticker <- ["CBA", "NAB", "BHP"] do %>
              <button
                type="button"
                phx-click="select_popular"
                phx-value-ticker={ticker}
                class="px-4 py-1.5 border border-[#e9ecef] rounded-md text-sm font-medium text-[#212529] hover:bg-[#f8f9fa] transition-colors"
              >
                <%= ticker %>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </.form>
    """
  end

  def key_statistics(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-[#e9ecef] p-6 shadow-sm">
      <h2 class="text-xl font-bold text-[#212529] mb-4">Key Statistics</h2>

      <div class="space-y-3">
        <.stat_row
          label="Current Price"
          value={format_currency(@quote.cf_last)}
        />

        <.stat_row
          label="Change"
          value={format_change(@quote.cf_netchng, @quote.pctchng)}
          colored={true}
        />

        <.stat_row
          label="Volume"
          value={format_number(@quote.cf_volume)}
        />

        <.stat_row
          label="Market Value"
          value={format_market_value(@quote.mkt_value)}
        />

        <.stat_row
          label="52W High"
          value={format_currency(Map.get(@quote, :"52wk_high"))}
        />
      </div>
    </div>
    """
  end

  def stat_row(assigns) do
    ~H"""
    <div class="flex justify-between items-center">
      <span class="text-[#6c757d] text-base"><%= @label %></span>
      <span class={[
        "text-base font-semibold",
        Map.get(assigns, :colored) && @value && value_color(@value) || "text-[#212529]"
      ]}>
        <%= @value %>
      </span>
    </div>
    """
  end

  def company_info(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-[#e9ecef] p-6 shadow-sm">
      <h2 class="text-xl font-bold text-[#212529] mb-4">Company Information</h2>
      <p class="text-[#212529] leading-relaxed">
        <%= @company.company_info %>
      </p>
    </div>
    """
  end

  def loading_spinner(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black/20 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 shadow-lg">
        <div class="flex items-center gap-3">
          <div class="animate-spin size-6 border-2 border-[#20705c] border-t-transparent rounded-full"></div>
          <span class="text-[#212529]">Loading company information...</span>
        </div>
      </div>
    </div>
    """
  end

  def error_message(assigns) do
    ~H"""
    <div class="fixed bottom-4 right-4 bg-[#dc3545] text-white px-6 py-4 rounded-lg shadow-lg max-w-md z-50">
      <%= @message %>
    </div>
    """
  end

  # Formatting helpers
  defp format_currency(nil), do: "N/A"
  defp format_currency(value) when is_number(value) do
    "$#{:erlang.float_to_binary(value * 1.0, decimals: 2)}"
  end

  defp format_number(nil), do: "N/A"
  defp format_number(value) when is_number(value) do
    Number.Delimit.number_to_delimited(value, precision: 0)
  end

  defp format_market_value(nil), do: "N/A"
  defp format_market_value(value) when is_number(value) do
    billions = value / 1_000_000_000
    "$#{:erlang.float_to_binary(billions, decimals: 2)}B"
  end

  defp format_change(nil, _), do: "N/A"
  defp format_change(_, nil), do: "N/A"
  defp format_change(change, pct) when is_number(change) and is_number(pct) do
    sign = if change >= 0, do: "+", else: ""
    change_val = :erlang.float_to_binary(abs(change) * 1.0, decimals: 2)
    pct_val = :erlang.float_to_binary(pct * 1.0, decimals: 2)
    "#{sign}$#{change_val} (#{sign}#{pct_val}%)"
  end

  defp value_color(value) do
    cond do
      String.starts_with?(value, "+") -> "text-[#198754]"
      String.starts_with?(value, "-") -> "text-[#dc3545]"
      true -> "text-[#212529]"
    end
  end
end

defmodule AsxCompanyInfoWeb.CompanyLive.Index do
  use AsxCompanyInfoWeb, :live_view

  alias AsxCompanyInfo.MarketData

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> assign(:comparison_tickers, [])
     |> assign(:comparison_data, %{})
     |> assign(:current_ticker, "")
     |> assign(:selected_info_ticker, nil)
     |> assign(:screen_width, nil)
     |> assign(:favourite_tickers, [])
     |> assign(:open_dropdown_ticker, nil)
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
        # Check ticker limit based on screen width
        max_tickers = get_max_tickers(socket.assigns.screen_width)
        current_count = length(socket.assigns.comparison_tickers)
        ticker_exists = normalized_ticker in socket.assigns.comparison_tickers

        if current_count >= max_tickers && !ticker_exists do
          Process.send_after(self(), :clear_error, 5000)
          error_message = "#{get_screen_size_message(socket.assigns.screen_width)} Please remove a ticker first."
          {:noreply, assign(socket, :error, error_message)}
        else
          send(self(), {:fetch_data, normalized_ticker})

          {:noreply,
           socket
           |> assign(:loading, true)
           |> assign(:error, nil)
           |> assign(:current_ticker, normalized_ticker)
           |> assign(:form, to_form(%{"ticker" => normalized_ticker}))}
        end

      {:error, error_message} ->
        {:noreply, assign(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("select_popular", %{"ticker" => ticker}, socket) do
    # Check ticker limit based on screen width
    max_tickers = get_max_tickers(socket.assigns.screen_width)
    current_count = length(socket.assigns.comparison_tickers)
    ticker_exists = ticker in socket.assigns.comparison_tickers

    if current_count >= max_tickers && !ticker_exists do
      Process.send_after(self(), :clear_error, 5000)
      error_message = "#{get_screen_size_message(socket.assigns.screen_width)} Please remove a ticker first."
      {:noreply, assign(socket, :error, error_message)}
    else
      send(self(), {:fetch_data, ticker})

      {:noreply,
       socket
       |> assign(:loading, true)
       |> assign(:error, nil)
       |> assign(:current_ticker, ticker)
       |> assign(:form, to_form(%{"ticker" => ticker}))}
    end
  end

  @impl true
  def handle_event("remove_ticker", %{"ticker" => ticker}, socket) do
    comparison_tickers = Enum.reject(socket.assigns.comparison_tickers, &(&1 == ticker))
    comparison_data = Map.delete(socket.assigns.comparison_data, ticker)

    # Update selected_info_ticker if removed ticker was selected
    selected_info_ticker =
      if socket.assigns.selected_info_ticker == ticker do
        List.first(comparison_tickers)
      else
        socket.assigns.selected_info_ticker
      end

    {:noreply,
     socket
     |> assign(:comparison_tickers, comparison_tickers)
     |> assign(:comparison_data, comparison_data)
     |> assign(:selected_info_ticker, selected_info_ticker)
     |> assign(:open_dropdown_ticker, nil)}
  end

  @impl true
  def handle_event("select_info_ticker", %{"ticker" => ticker}, socket) do
    {:noreply, assign(socket, :selected_info_ticker, ticker)}
  end

  @impl true
  def handle_event("update_screen_width", %{"width" => width}, socket) do
    {:noreply, assign(socket, :screen_width, width)}
  end

  @impl true
  def handle_event("toggle_dropdown", %{"ticker" => ticker}, socket) do
    new_dropdown = if socket.assigns.open_dropdown_ticker == ticker, do: nil, else: ticker
    {:noreply, assign(socket, :open_dropdown_ticker, new_dropdown)}
  end

  @impl true
  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :open_dropdown_ticker, nil)}
  end

  @impl true
  def handle_event("toggle_favourite", %{"ticker" => ticker}, socket) do
    # Don't allow popular stocks to be favorited
    if ticker in ["CBA", "NAB", "BHP"] do
      {:noreply, socket}
    else
      favourite_tickers = socket.assigns.favourite_tickers

      new_favourites =
        if ticker in favourite_tickers do
          # Remove from favourites
          Enum.reject(favourite_tickers, &(&1 == ticker))
        else
          # Add to favourites if less than 3
          if length(favourite_tickers) < 3 do
            favourite_tickers ++ [ticker]
          else
            favourite_tickers
          end
        end

      {:noreply,
       socket
       |> assign(:favourite_tickers, new_favourites)
       |> assign(:open_dropdown_ticker, nil)}
    end
  end

  @impl true
  def handle_info({:fetch_data, ticker}, socket) do
    # Check ticker limit based on screen width (default to mobile if screen_width not yet set)
    max_tickers = get_max_tickers(socket.assigns.screen_width)
    current_count = length(socket.assigns.comparison_tickers)
    ticker_exists = ticker in socket.assigns.comparison_tickers

    if current_count >= max_tickers && !ticker_exists do
      Process.send_after(self(), :clear_error, 5000)
      error_message = "#{get_screen_size_message(socket.assigns.screen_width)} Please remove a ticker first."
      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:error, error_message)}
    else
      # Fetch both company info and quote data in parallel
      tasks = [
        Task.async(fn -> MarketData.fetch_company_info(ticker) end),
        Task.async(fn -> MarketData.fetch_quote(ticker) end)
      ]

      results = Task.await_many(tasks, :timer.seconds(10))

      case results do
        [{:ok, company_data}, {:ok, quote_data}] ->
          # Add ticker to comparison if not already present
          comparison_tickers =
            if ticker in socket.assigns.comparison_tickers do
              socket.assigns.comparison_tickers
            else
              socket.assigns.comparison_tickers ++ [ticker]
            end

          comparison_data =
            Map.put(socket.assigns.comparison_data, ticker, %{
              company: company_data,
              quote: quote_data
            })

          # Always set selected_info_ticker to the most recently searched ticker
          selected_info_ticker = ticker

          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:comparison_tickers, comparison_tickers)
           |> assign(:comparison_data, comparison_data)
           |> assign(:selected_info_ticker, selected_info_ticker)
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
  end

  @impl true
  def handle_info(:clear_error, socket) do
    {:noreply, assign(socket, :error, nil)}
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

  defp get_max_tickers(screen_width) do
    cond do
      is_nil(screen_width) || screen_width < 640 -> 2  # Mobile
      screen_width < 1024 -> 3  # Tablet
      true -> 4  # Desktop
    end
  end

  defp get_screen_size_message(screen_width) do
    cond do
      is_nil(screen_width) || screen_width < 640 -> "Mobile users can only compare 2 tickers at once."
      screen_width < 1024 -> "Your screen size allows up to 3 tickers at once."
      true -> "Your screen size allows up to 4 tickers at once."
    end
  end

  defp responsive_ticker_classes(index) do
    cond do
      index >= 4 -> "hidden"
      index >= 3 -> "hidden lg:flex lg:flex-1"
      index >= 2 -> "hidden sm:flex sm:flex-1"
      true -> "flex flex-1"
    end
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
            Compare ASX Tickers
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

        <!-- Popular and Favourite Stocks -->
        <div class={[
          "flex gap-4",
          Map.get(assigns, :centered) && "flex-col" || "flex-col sm:flex-row"
        ]}>
          <!-- Popular Stocks -->
          <div class="flex-1">
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

          <!-- Favourite Stocks -->
          <%= if length(@favourite_tickers) > 0 do %>
            <div class="flex-1">
              <p class="text-sm text-[#6c757d] mb-2">Favourite stocks:</p>
              <div class="flex gap-2">
                <%= for ticker <- @favourite_tickers do %>
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
          <% end %>
        </div>
      </div>
    </.form>
    """
  end

  def key_statistics(assigns) do
    # Find ticker with highest and lowest percentage change
    {best_ticker, worst_ticker} =
      if length(assigns.comparison_tickers) > 1 do
        ticker_pcts =
          assigns.comparison_tickers
          |> Enum.map(fn ticker ->
            quote = assigns.comparison_data[ticker][:quote]
            pct = if quote, do: quote.pctchng || 0, else: 0
            {ticker, pct}
          end)

        best = ticker_pcts |> Enum.max_by(fn {_ticker, pct} -> pct end, fn -> {nil, 0} end)
        worst = ticker_pcts |> Enum.min_by(fn {_ticker, pct} -> pct end, fn -> {nil, 0} end)

        # Only mark best/worst if they're different (i.e., not all tickers have same pctchng)
        if best != worst do
          {elem(best, 0), elem(worst, 0)}
        else
          {nil, nil}
        end
      else
        {nil, nil}
      end

    assigns = assigns |> assign(:best_ticker, best_ticker) |> assign(:worst_ticker, worst_ticker)

    ~H"""
    <div class="bg-white rounded-lg border border-[#e9ecef] p-6 shadow-sm">
      <h2 class="text-xl font-bold text-[#212529] mb-4">Key Statistics</h2>

      <!-- Ticker Headers -->
      <div class="flex items-center gap-2 mb-4">
        <div class="w-32 text-[#6c757d] text-sm">Ticker</div>
        <%= for {ticker, index} <- Enum.with_index(@comparison_tickers) do %>
          <div class={[
            "items-center gap-2",
            responsive_ticker_classes(index)
          ]}>
            <div class="flex-1 flex items-center justify-end gap-1">
              <span
                class={[
                  "text-[#212529] font-semibold text-sm",
                  ticker == @best_ticker && "border-2 border-[#198754] rounded px-2 py-0.5",
                  ticker == @worst_ticker && "border-2 border-[#dc3545] rounded px-2 py-0.5"
                ]}
                title={
                  cond do
                    ticker == @best_ticker -> "Best performer out of the selection"
                    ticker == @worst_ticker -> "Worst performer out of the selection"
                    true -> nil
                  end
                }
              ><%= ticker %></span>
              <%= if ticker not in ["CBA", "NAB", "BHP"] do %>
                <div class="relative">
                  <button
                    type="button"
                    phx-click="toggle_dropdown"
                    phx-value-ticker={ticker}
                    class="text-[#6c757d] hover:text-[#212529] hover:bg-[#f8f9fa] rounded-full p-1 transition-colors"
                    title="More actions"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.75a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5ZM12 12.75a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5ZM12 18.75a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5Z" />
                    </svg>
                  </button>
                  <%= if @open_dropdown_ticker == ticker do %>
                    <div class="absolute right-0 top-full mt-1 bg-white border border-[#e9ecef] rounded-lg shadow-lg py-1 z-10 min-w-[160px]" phx-click-away="close_dropdown">
                      <button
                        type="button"
                        phx-click="toggle_favourite"
                        phx-value-ticker={ticker}
                        class="w-full px-4 py-2 text-left text-sm hover:bg-[#f8f9fa] transition-colors flex items-center gap-2"
                      >
                        <%= if ticker in @favourite_tickers do %>
                          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-4 text-[#ffc107]">
                            <path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z" clip-rule="evenodd" />
                          </svg>
                          <span class="text-[#212529]">unfavourite</span>
                        <% else %>
                          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4 text-[#6c757d]">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z" />
                          </svg>
                          <span class="text-[#212529]">favourite</span>
                        <% end %>
                      </button>
                      <button
                        type="button"
                        phx-click="remove_ticker"
                        phx-value-ticker={ticker}
                        class="w-full px-4 py-2 text-left text-sm hover:bg-[#f8f9fa] transition-colors flex items-center gap-2"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4 text-[#dc3545]">
                          <path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                        </svg>
                        <span class="text-[#dc3545]">Remove</span>
                      </button>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <button
                  type="button"
                  phx-click="remove_ticker"
                  phx-value-ticker={ticker}
                  class="text-[#6c757d] hover:text-[#dc3545] hover:bg-[#f8f9fa] rounded-full p-1 transition-colors"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 12H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                  </svg>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Statistics Rows -->
      <div class="space-y-3">
        <.comparison_stat_row
          label="Current Price"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
          formatter={&format_currency/1}
          field={:cf_last}
        />

        <.comparison_change_row
          label="Change"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
        />

        <.comparison_change_difference_row
          label="Change Difference"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
        />

        <.comparison_trend_row
          label="Trend Indicator"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
        />

        <.comparison_stat_row
          label="52W High"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
          formatter={&format_currency/1}
          field={:"52wk_high"}
        />

        <.comparison_stat_row
          label="52W Low"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
          formatter={&format_currency/1}
          field={:"52wk_low"}
        />

        <.comparison_stat_row
          label="Volume"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
          formatter={&format_number/1}
          field={:cf_volume}
        />

        <.comparison_stat_row
          label="Market Value"
          tickers={@comparison_tickers}
          comparison_data={@comparison_data}
          formatter={&format_market_value/1}
          field={:mkt_value}
        />


      </div>
    </div>
    """
  end

  def comparison_stat_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-32 text-[#6c757d] text-sm"><%= @label %></div>
      <%= for {ticker, index} <- Enum.with_index(@tickers) do %>
        <% quote = @comparison_data[ticker][:quote] %>
        <% value = if quote, do: Map.get(quote, @field), else: nil %>
        <div class={[
          "items-center gap-1",
          responsive_ticker_classes(index)
        ]}>
          <div class="flex-1 text-right text-[#212529] font-semibold text-sm">
            <%= @formatter.(value) %>
          </div>
          <div class="size-6"></div>
        </div>
      <% end %>
    </div>
    """
  end

  def comparison_change_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-32 text-[#6c757d] text-sm"><%= @label %></div>
      <%= for {ticker, index} <- Enum.with_index(@tickers) do %>
        <% quote = @comparison_data[ticker][:quote] %>
        <% change_val = if quote, do: format_change(quote.cf_netchng, quote.pctchng), else: "N/A" %>
        <% pct_binary = if quote.pctchng, do: "#{quote.pctchng}", else: "N/A" %>
        <div class={[
          "items-center gap-1",
          responsive_ticker_classes(index)
        ]}>
          <div class={[
            "flex-1 text-right font-semibold text-sm",
            value_color(pct_binary)
          ]}>
            <%= change_val %>
          </div>
          <div class="size-6"></div>
        </div>
      <% end %>
    </div>
    """
  end

  def comparison_change_difference_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-32 text-[#6c757d] text-sm" title="Pourcentage difference with the ticker on the right side"><%= @label %></div>
      <%= for {ticker, index} <- Enum.with_index(@tickers) do %>
        <div class={[
          "items-center gap-1",
          responsive_ticker_classes(index)
        ]}>
          <%= if index <= length(@tickers) - 1 do %>
            <% next_ticker = Enum.at(@tickers, index + 1) %>
            <% diff_str =
              with current_quote when not is_nil(current_quote) <- @comparison_data[ticker][:quote],
                   next_quote when not is_nil(next_quote) <- @comparison_data[next_ticker][:quote],
                   current_pct when not is_nil(current_pct) <- current_quote.pctchng,
                   next_pct when not is_nil(next_pct) <- next_quote.pctchng do
                diff = current_pct - next_pct
                format_percentage_diff(diff)
              else
                _ -> "N/A"
              end
            %>
            <div
              class="flex-1 text-right font-semibold text-sm text-[#212529]"
              title="Pourcentage difference with the ticker on the right side"
            >
              <%= diff_str %>
            </div>
          <% else %>
            <div class="flex-1"></div>
          <% end %>
          <div class="size-6"></div>
        </div>
      <% end %>
    </div>
    """
  end

  def comparison_trend_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-32 text-[#6c757d] text-sm"><%= @label %></div>
      <%= for {ticker, index} <- Enum.with_index(@tickers) do %>
        <% quote = @comparison_data[ticker][:quote] %>
        <% trend = if quote, do: calculate_trend_indicator(quote), else: "N/A" %>
        <div class={[
          "items-center gap-1",
          responsive_ticker_classes(index)
        ]}>
          <div
            class={[
              "flex-1 text-right font-semibold text-sm",
              trend_color(trend)
            ]}
            title="Trend direction between the lowest price and highest price within 52-week range"
          >
            <%= trend %>
          </div>
          <div class="size-6"></div>
        </div>
      <% end %>
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
      <div class="mb-4">
        <form phx-change="select_info_ticker">
          <select
            name="ticker"
            class="w-auto p-2 border border-[#e9ecef] rounded-md focus:outline-none focus:ring-2 focus:ring-[#20705c] focus:border-transparent text-[#212529] font-medium"
          >
            <%= for ticker <- @tickers do %>
              <option value={ticker} selected={ticker == @selected_ticker}>
                <%= ticker %> Company Information
              </option>
            <% end %>
          </select>
        </form>
      </div>
      <%= if @company do %>
        <p class="text-[#212529] leading-relaxed">
          <%= @company.company_info %>
        </p>
      <% end %>
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

  defp format_percentage_diff(diff) when is_number(diff) do
    sign = if diff >= 0, do: "+", else: "-"
    pct_val = :erlang.float_to_binary(abs(diff) * 1.0, decimals: 2)
    "#{sign}#{pct_val}%"
    # "#{pct_val}%"
  end

  defp format_percentage_diff(_), do: "N/A"

  defp calculate_trend_indicator(quote) do
    # Calculate position within 52-week range

    low = Map.get(quote, :"52wk_low") || Map.get(quote, :yrlow)
    high = Map.get(quote, :"52wk_high") || Map.get(quote, :yrhigh)
    current = quote.cf_last

    case {low, high, current} do
      {low_val, high_val, current_val} when is_number(low_val) and is_number(high_val) and is_number(current_val) ->
        range = high_val - low_val
        if range > 0 do
          position = (current_val - low_val) / range * 100

          cond do
            position >= 80 -> "Strong Upward"
            position >= 60 -> "Upward"
            position >= 40 -> "Neutral"
            position >= 20 -> "Downward"
            true -> "Strong Downward"
          end
        else
          "Neutral"
        end
      _ ->
        "N/A"
    end
  end

  defp trend_color(trend) do
    case trend do
      "Strong Upward" -> "text-[#198754]"
      "Upward" -> "text-[#28a745]"
      "Neutral" -> "text-[#6c757d]"
      "Downward" -> "text-[#fd7e14]"
      "Strong Downward" -> "text-[#dc3545]"
      _ -> "text-[#212529]"
    end
  end
end

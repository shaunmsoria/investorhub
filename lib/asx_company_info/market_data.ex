defmodule AsxCompanyInfo.MarketData do
  @moduledoc """
  Context for fetching market data from external API.
  """

  alias AsxCompanyInfo.MarketData.{Company, Quote}

  @doc """
  Fetches company information for a given ticker.
  Returns {:ok, %Company{}} or {:error, reason}
  """
  def fetch_company_info(ticker) do
    url = "#{base_url()}/api/market_data/company_information?ticker=#{ticker}"

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            {:ok, %Company{
              ticker: data["ticker"],
              company_info: data["company_info"]
            }}
          {:error, _} ->
            {:error, :invalid_json}
        end

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, :bad_request}

      {:ok, %HTTPoison.Response{}} ->
        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches current quote data for a given ticker.
  Returns {:ok, %Quote{}} or {:error, reason}
  """
  def fetch_quote(ticker) do
    url = "#{base_url()}/api/market_data/quotes?market_key=asx&listing_key=#{ticker}"

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            quote_data = data["quote"] || %{}
            {:ok, %Quote{
              symbol: data["symbol"],
              cf_last: quote_data["cf_last"],
              cf_netchng: quote_data["cf_netchng"],
              pctchng: quote_data["pctchng"],
              cf_volume: quote_data["cf_volume"],
              mkt_value: quote_data["mkt_value"],
              "52wk_high": quote_data["52wk_high"]
            }}
          {:error, _} ->
            {:error, :invalid_json}
        end

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, :bad_request}

      {:ok, %HTTPoison.Response{}} ->
        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp base_url do
    Application.get_env(:asx_company_info, :api_base_url, "https://public.investorhub.com")
  end

  defp api_key do
    Application.get_env(:asx_company_info, :api_key, "btb9w-fNTk929B38ePAgw4_kgDpb2r7qq7zgXJGZI5s")
  end

  defp headers do
    [
      {"Authorization", "Bearer #{api_key()}"},
      {"Content-Type", "application/json"}
    ]
  end
end

defmodule AsxCompanyInfo.MarketData.Quote do
  @moduledoc """
  Struct for stock quote data.
  """

  defstruct [
    :symbol,
    :cf_last,           # Current price
    :cf_netchng,        # Price change
    :pctchng,           # Percentage change
    :cf_volume,         # Volume
    :mkt_value,         # Market value
    :"52wk_high",        # 52 week high
    :"52wk_low",        # 52 week low
  ]
end

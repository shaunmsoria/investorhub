# AsxCompanyInfo



# Assumptions

I made the following assumptions:

1) Since the user isn't logged in to the app in its current version, the favourites are saved in a variable. In production with an identified user and database, I would store the user's favourite stocks either in the user's table or in a dedicated table in the database.

2) Since the app will be running on a local machine with ASDF using the GitHub link, the installation process below shouldn't cause any issues.



# Installation Instructions

* Run: `gh repo clone shaunmsoria/investorhub`  in the folder where you want to have the ASX Company Info running
* Run: `cd asx_company_info`
* Run: `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
* Visit [`localhost:4000`](http://localhost:4000) from your browser

# Approach Debrief

After analysing the business case, the following problems were identified as core issues:
* Inability to effectively compare multiple stocks at once
* Inability for the user to save favourites or name a selection for reuse


## Inability to effectively compare multiple stocks at once

### Source: 

* User Survey: 89% of users want side-by-side functionality
* User Survey: 84% of users find the current multi-tab approach "frustrating" or "very frustrating"
* Pain Points: Inefficient Workflow
* Pain Points: Cognitive Overload
* Pain Points: Mobile Limitations
* Pain Points: Missed Opportunities
* User Behavior Analysis: Opening 3-5 browser tabs on average
* User Behavior Analysis: Manually switching between tabs to compare metrics
* User Behavior Analysis: Abandoning comparison tasks due to complexity (32% drop-off rate)

### Reasoning:

* Based on User Survey, Pain Points, and User Behavior Analysis, it's clear our current users need to spot potential trading opportunities by comparing multiple stocks at once. Easing the process will allow the user to focus more resources on finding profitable opportunities rather than having to overcome bad UI/UX.

### Solution:

* Implement a side-by-side comparison allowing the user to compare up to 4 stocks at once on desktop (adjusted based on screen resolution: 2 stocks at once for mobile and 3 stocks at once on tablets).

* The data displayed needs to be focused on key statistics, as it was revealed in the "User Behavior Analysis" that users want to compare metrics and have smart comparison tools to help them decipher potential trends.

* The Key Statistics displayed are:
    * Ticker: (Stock Ticker) 
        -> Helps users clearly group the key statistics underneath each ticker

    * Current Price: Current Stock Price 
        -> Allows users to keep track of the stock position

    * Change: Represents the delta in price in fiat and the percentage 
        -> Allows users to assess volatility and profitability

    * Change Difference: Represents the difference in percentage between the delta percentage of the stock vs the stock on the right side 
        -> Helps users compare the stock volatility

    * Trend Indicator: Allows users to identify the stock trend versus its 52W low and 52W high
        -> Helps users evaluate the stock's room for growth or correction

    * 52W High: The highest price the stock reached in the last 52 weeks
        -> Helps users identify stock top ceiling

    * 52W Low: The lowest price the stock reached in the last 52 weeks
        -> Helps users identify stock low ceiling

    * Volume: Number of shares traded in the day
        -> Helps users assess volatility

    * Market Value: Total value of company's outstanding shares
        -> Helps users assess volatility

* The Key Statistics also have a Best/Worst performer indicator that shows with a green or red border respectively around the Ticker, highlighting the best and worst performer out of the selection at a glance. The performance is based on the Change in percentage value.
    If all stocks have a Change percentage equal to or 0% (before opening hours), no borders will be displayed.

* Remove Ticker: There is a button on the right side of the ticker allowing the user to remove a ticker from the selection. The user can add another ticker by searching for it or clicking on the Popular stocks or Favourite stocks buttons.
    -> Helps users manipulate the selection as needed for better UX.

* Company Information shows the company information of the latest selected stock. The user can also select which stock from the selection they would like to peruse.
    -> Helps users assess the company context.

### Justifications:

* I decided to focus on key metrics users will need to ascertain trade opportunities without overwhelming them with unnecessary data. That's why I didn't add charts, and focused as much as possible on providing a clean and simple UI allowing users to make business decisions without cognitive overload.

* I also decided to not display the company info under each ticker column as it would look compressed and generally the comparison metrics used by the users should be mentioned in the key statistics for better readability.
Users shouldn't need to read a blob of text to make comparisons; the company information is supposed to provide context to the user and therefore being selectable in a dropdown is sufficient.

* I also added a remove button next to the ticker's name to allow flexibility on the stock selection.

* I also decided to limit the mobile version ticker selection range to 2 and tablets to 3 to keep the key metrics from being crammed and ensure they're easily readable. The limited selection range on mobile and tablets is compensated by the interface's quick selection capabilities. 

* I also decided not to implement live updates as it's not mentioned in any of the case study data sources (e.g. Pain Points Identified, Current User Behavior Analysis...), and therefore concluded it's not part of the core problem to solve for the users.



## Inability for the user to save favourites or name a selection for reuse

### Source: 

* Pain Points: Data Loss
* User Behavior Analysis: Abandoning comparison tasks due to complexity (32% drop-off rate)
* User Behavior Analysis: Taking screenshots or notes to track differences

### Reasoning:

* Based on Pain Points and User Behavior Analysis, it appears that users can have a particular selection of tickers they would like to check on a regular basis, and reducing the UX friction will entice users to come back to us to use our comparison tools.

### Solution:

* Implemented a favourite functionality allowing users to access the metrics of their favourite stocks with one click of a button
* For stocks that are not popular stocks in our interface, a vertical three-dot button will appear instead of the remove button next to the Ticker in the Key Statistics, allowing the user to either remove the ticker from the selection or add/remove the stock in the `Favourite stocks` section.
* The `Favourite stocks` section will appear on the right side of the `Popular stocks` section on desktop/tablets and underneath on mobile.
* The `Favourite stocks` section will allow users to expand the quick access functionalities, reducing UX friction and enticing users to come back to our platform.
* If the user removes all the favourite stocks from the `Favourite stocks` section, the section will disappear to remove cognitive load from the customer.

### Justifications:

* I decided not to add the named selection because I considered it nice to have. If the user can set a favourite stock selection and have quick access to it, that's all the functionality they need to quickly compare multiple stocks on a regular basis.

* If users request more stocks to be added, we can expand the max limit from 3 to 5 or more. If users request the possibility to save multiple stock selections, it can be considered in the future, but before investing time in that feature, I think we can use the `Favourite Stocks` section to see if there is demand and assess from there.


        
# Additional Features:

1) Improve the favourite/unfavourite UX by moving it to another location, allowing the remove button to be always quickly accessible for stocks not present in the `Popular stocks` section
2) Add named selection of tickers to allow more UX flexibility to the user
3) Live updates: allow users to see the price change over time if not available by default
4) Add visual charts either under or above company information for the last selected ticker to provide additional context to the user
5) Save user stock selections to enable more in-depth comparison features




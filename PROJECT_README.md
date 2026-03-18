# ASX Company Information Dashboard

A modern Phoenix LiveView application for searching and displaying Australian Stock Exchange (ASX) company information and key financial statistics.

## 🚀 Features

- **Real-time Search**: Search for ASX-listed companies by ticker symbol
- **Live Updates**: Powered by Phoenix LiveView for real-time interactivity
- **Key Statistics**: Display current price, price changes, volume, market value, and 52-week high
- **Company Information**: View detailed company descriptions
- **Responsive Design**: Clean two-column layout that adapts to different screen sizes
- **Error Handling**: Comprehensive validation and error messages
- **Popular Stocks**: Quick access to commonly searched stocks (CBA, NAB, BHP)

## 📋 Prerequisites

- Elixir 1.15+
- Erlang/OTP 25+
- Node.js and npm (for assets)

## 🛠️ Installation

1. **Clone or navigate to the project directory**:
   ```bash
   cd asx_company_info
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   ```

3. **Install Node.js dependencies**:
   ```bash
   cd assets && npm install && cd ..
   ```

4. **Start the Phoenix server**:
   ```bash
   mix phx.server
   ```

5. **Visit the application**:
   Open your browser and navigate to [`http://localhost:4000`](http://localhost:4000)

## 🏗️ Project Structure

```
lib/
├── asx_company_info/
│   ├── application.ex              # OTP application
│   └── market_data/
│       ├── market_data.ex          # Context module for API calls
│       ├── company.ex              # Company struct
│       └── quote.ex                # Quote struct
│
├── asx_company_info_web/
│   ├── live/
│   │   └── company_live/
│   │       ├── index.ex            # Main LiveView module
│   │       └── index.html.heex     # Template
│   ├── router.ex                   # Routes configuration
│   └── endpoint.ex                 # Phoenix endpoint
│
└── config/
    ├── config.exs                  # Base configuration
    ├── dev.exs                     # Development config
    └── runtime.exs                 # Runtime config (API settings)
```

## 🔑 API Configuration

The application uses InvestorHub's public API. Configuration is in `config/runtime.exs`:

```elixir
config :asx_company_info,
  api_base_url: "https://public.investorhub.com",
  api_key: "btb9w-fNTk929B38ePAgw4_kgDpb2r7qq7zgXJGZI5s"
```

You can override these with environment variables:
- `API_BASE_URL`: Base URL for the API
- `API_KEY`: API authentication key

## 🎨 Design

The application follows a clean, professional design with:
- **Primary Color**: `#20705c` (teal green)
- **Background**: Light gray `#f8f9fa`
- **Cards**: White with subtle borders
- **Responsive Layout**: Two-column desktop, single-column mobile

## 📦 Dependencies

Key dependencies include:
- `phoenix` (~> 1.8.5) - Web framework
- `phoenix_live_view` (~> 1.1.0) - Real-time interactivity
- `httpoison` (~> 2.0) - HTTP client for API calls
- `number` (~> 1.0) - Number formatting
- `tailwind` (~> 0.3) - CSS framework

## 🧪 Testing

Run tests with:
```bash
mix test
```

## 📝 Usage

1. **Search by Ticker**: Enter a stock ticker (e.g., "CBA") in the search box
2. **Quick Access**: Click one of the popular stock buttons
3. **View Results**: See key statistics and company information side-by-side
4. **Search Again**: The search box stays visible for easy additional searches

## 🔍 How It Works

### Search Flow
1. User enters ticker or clicks popular stock
2. Input is validated (3+ characters, alphanumeric)
3. Loading state is displayed
4. Parallel API calls fetch company info and quote data
5. Results are displayed in a two-column layout
6. Errors are handled with user-friendly messages

### LiveView Components
- `search_form/1` - Search input and popular stocks
- `key_statistics/1` - Financial metrics display
- `company_info/1` - Company description
- `loading_spinner/1` - Loading state indicator
- `error_message/1` - Error notifications

## 🎯 Features Implemented

### Functionality ✅
- [x] Search for ASX tickers with validation
- [x] Display key financial statistics
- [x] Show company information
- [x] Handle loading and error states
- [x] Clickable popular stock suggestions
- [x] Retain ticker value after search
- [x] Real-time updates via LiveView

### Design ✅
- [x] Clean, professional InvestorHub-style design
- [x] Two-column responsive layout
- [x] Consistent card styling and alignment
- [x] Proper color scheme and typography
- [x] Green primary color for buttons
- [x] Consistent font sizes and spacing

### Technical ✅
- [x] Elixir/Phoenix implementation
- [x] LiveView for real-time interactivity
- [x] Proper error handling and validation
- [x] Parallel API calls using Task
- [x] Responsive design with Tailwind
- [x] Clean separation of concerns
- [x] Type safety with structs

## 🚀 Development

To start your Phoenix server in development mode:
```bash
mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check the deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## 📖 Learn More

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## 📄 License

This project was created as part of a technical interview task.

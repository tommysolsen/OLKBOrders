HTTPoison.start
defmodule OLKBParser do
  @moduledoc"""
  A module for retrieving and parsing the OLKB order queue
  """

  @doc"""
  Get the contents of the orders page
  """
  def contents do
    case HTTPoison.get "https://orders.olkb.com" do
      {:ok, %HTTPoison.Response{} = resp} -> { :ok, resp.body }
      {:error, _} = error -> error 
    end
  end
  def extract_list({:ok, body}) do
    Floki.find(body, "ol > li")
  end

  def getnumber(body, number) when is_list(body) do
    getnumber(body, number, 0)
  end

  def getnumber([{"li", _, [str | _]} | rest], number, i) do
    case str == number do
      true  -> {:ok, i}
      false -> getnumber(rest, number, i + 1)
    end
  end

  def getnumber([], _, _) do
    { :error, "No number found" }
  end

  def getnumber({:error, _ } = all), do: all

  def get(number) do
    OLKBParser.contents
    |> OLKBParser.extract_list
    |> OLKBParser.getnumber(number)
  end
end

defmodule Pushover do
  defstruct [:message, :title, :token, :user, :device]
  @moduledoc"""
  Creates and sends a message to the pushover apis
  """

  @doc"""
  Creates an empty message
  """
  def new do
    %Pushover{}
  end

  @doc"""
  Adds the message to the payload

  iex> Pushover.with_message(%{}, "test")
  %{message: "test"}
  """
  def with_message(%Pushover{} = obj, msg) do
    Map.merge(obj, %{message: msg})
  end

  @doc"""
  Adds a title to the payload
  """
  def with_title(%Pushover{} = obj, title) do
    Map.merge(obj, %{title: title})
  end


  @doc"""
  Fetches api tokens from config and adds it to the payload
  """
  def add_std_tokens(%Pushover{} = obj) do
    Map.merge(obj, %{
      token: Application.get_env(:olkb_parser, :pushover_api_token),
      user: Application.get_env(:olkb_parser, :pushover_user_token)
            })
  end

  @doc"""
  Sends message
  """
  def send_message(%Pushover{} = payload) do
    case JSON.encode(payload) do
      {:ok, results} ->
        HTTPoison.post! "https://api.pushover.net/1/messages.json", results, [{ "Content-Type", "application/json" }]
      {:error, error} -> error
    end
  end
end

defmodule ParseChecker do
  def watch(number) do
    watch(number, 0)
  end

  def watch(number, last_number) do
    IO.puts("Checking OLKB for order status")
    response = OLKBParser.get(number)
    {:ok, value} = response 
    case response do
      {:ok, value} ->
        case Pushover.new
        |> Pushover.with_message("Your position in the queue has changed: You are now ##{value} in the queue.")
        |> Pushover.with_title("OLKB queue changed")
        |> Pushover.add_std_tokens
        |> Pushover.send_message do
          %HTTPoison.Response{} = response ->
            IO.puts "OK"
          %HTTPoison.Error{} = _ ->
            IO.puts "Sending message to pushover failed."
        end
      {:error, number_error} ->
        case Pushover.new
        |> Pushover.with_message("JSON encoding of a message has failed #{number_error}")
        |> Pushover.add_std_tokens
        |> Pushover.send_message do
          %HTTPoison.Response{} = _-> IO.puts("Sending error succeeded")
        end
    end
    Process.sleep(60000 * 15)
    watch(number, value)
  end
end


IO.puts "Starting OLKB checker" 
ParseChecker.watch(Application.get_env(:olkb_parser, :order))

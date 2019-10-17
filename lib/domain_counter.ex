defmodule DomainCounter do

  use Plug.Router

  plug :match
  plug :dispatch

  defp get_links(from, to) do
    Redix.command!(:redis, ["ZRANGEBYSCORE", "domains", from, to])
  end

  defp upload_link(url, current_time) do
    Redix.command!(:redis, ["ZADD", "domains", current_time, url])
  end

  defp get_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when not is_nil(host) -> host
      %URI{path: path} when not is_nil(path) -> path
      _ -> raise ArgumentError, message: "Bad URL #{url}"
    end
  end

  get "/visited_domains" do
    result = try do
      # MatchError если нет нужных полей
      %{"from" => from_s, "to" => to_s} = Plug.Conn.Query.decode(conn.query_string)
      # ArgumentError если не числа
      [from, to] = Enum.map([from_s, to_s], &String.to_integer/1)
      # Проверяем явно косячные запросы чтоб не пришлось зря мотаться в базу
      cond do
        from < 0 or to < 0 -> {:error, "'from' and 'to' should not be negative"}
        from > to -> {:error, "From should be <= than To"}
        true -> {:ok, get_links(from, to)}
      end
    rescue
      MatchError -> {:error, "Missing 'from' and 'to' fields"}
      ArgumentError -> {:error, "'from' and 'to' should be integers"}
    end
    
    {status_code, payload} = case result do
      {:error, err_msg} -> {400, %{"status" => err_msg}}
      {:ok, links} -> {200, %{"status" => "ok", "domains" => links}}
    end

    send_resp(conn, status_code, Poison.encode!(payload))
  end

  post "/visited_links" do
    current_time = DateTime.utc_now |> DateTime.to_unix
    {:ok, links_json, _} = Plug.Conn.read_body(conn)
    %{"links" => links} = Poison.decode!(links_json)

    {status_code, status_msg} = try do
      # Сначала проверим все ссылки на корректность
      # А уже потом будем грузить в базу
      # Чтобы избежать частичных загрузок
      links |> Enum.map(&get_domain/1) |> Enum.uniq |> Enum.map(&upload_link(&1, current_time))
      {200, "ok"}
    rescue
      e in ArgumentError -> {400, e.message}
    end
    
    send_resp(conn, status_code, Poison.encode!(%{"status" => status_msg}))
  end

  match _ do
    send_resp(conn, 404, "Nothing here!")
  end

end

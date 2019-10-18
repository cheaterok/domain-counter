defmodule DomainCounterTest do
  use ExUnit.Case
  use Plug.Test
  doctest DomainCounter

  import Mock

  @opts DomainCounter.init([])

  @redis_set "domains"
  @current_time 1571261654

  setup_with_mocks([
    {DateTime, [], [
      utc_now: fn() -> :ok end,
      to_unix: fn(_) -> @current_time end
      ]},
    {Redix, [], [command!: 
        fn
          (_, ["ZADD", _, _, _]) -> :ok
          (_, ["ZRANGEBYSCORE", _, _, _]) -> []
        end
      ]
    }
  ]) do
    :ok
  end

  test "non-existent page" do
    conn =
      :get
      |> conn("/void")
      |> DomainCounter.call(@opts)

    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == "Nothing here!"
  end

  test "add domains" do
    links = [
      "https://ya.ru",
      "https://ya.ru?q=123",
      "funbox.ru",
      "https://stackoverflow.com/questions/11828270/how-to-exit-the-vim-editor"
    ]
    
    conn =
      :post
      |> conn("/visited_links", Poison.encode!(%{"links" => links}))
      |> DomainCounter.call(@opts)
    
      assert conn.state == :sent
      assert conn.status == 200
      assert Poison.decode!(conn.resp_body) == %{"status" => "ok"}

      assert called Redix.command!(:redis, ["ZADD", @redis_set, @current_time, "ya.ru"])
      assert called Redix.command!(:redis, ["ZADD", @redis_set, @current_time, "funbox.ru"])
      assert called Redix.command!(:redis, ["ZADD", @redis_set, @current_time, "stackoverflow.com"])
  end

  test "add domain [incorrect link]" do
    conn = 
      :post
      |> conn("/visited_links", Poison.encode!(%{"links" => [""]}))
      |> DomainCounter.call(@opts)
    
    assert conn.state == :sent
    assert conn.status == 400
    assert Poison.decode!(conn.resp_body) == %{"status" => "Bad URL "}
  end

  test "add domain [wrong type]" do
    conn = 
      :post
      |> conn("/visited_links", Poison.encode!(%{"links" => 1234}))
      |> DomainCounter.call(@opts)
    
    assert conn.state == :sent
    assert conn.status == 400
    assert Poison.decode!(conn.resp_body) == %{"status" => "'links' should be list"}
  end

  test "add domain [wrong types]" do
    conn = 
      :post
      |> conn("/visited_links", Poison.encode!(%{"links" => [1, "45", 13.0, ["test"]]}))
      |> DomainCounter.call(@opts)
    
    assert conn.state == :sent
    assert conn.status == 400
    assert Poison.decode!(conn.resp_body) == %{"status" => "'links' members should be strings"}
  end

  test "add domain [no links]" do
    conn = 
      :post
      |> conn("/visited_links", Poison.encode!(%{"random" => 1234}))
      |> DomainCounter.call(@opts)
    
    assert conn.state == :sent
    assert conn.status == 400
    assert Poison.decode!(conn.resp_body) == %{"status" => "Bad arguments"}
  end

  test "get domains" do
    {from, to} = {12345, 54321}
    conn = 
      :get
      |> conn("/visited_domains?from=#{from}&to=#{to}")
      |> DomainCounter.call(@opts)
    
    assert conn.state == :sent
    assert conn.status == 200
    assert Poison.decode!(conn.resp_body) == %{"status" => "ok", "domains" => []}

    assert called Redix.command!(:redis, ["ZRANGEBYSCORE", @redis_set, from, to])
  end

  test "get domain [missing parameters]" do
    conn = 
        :get
        |> conn("/visited_domains")
        |> DomainCounter.call(@opts)
    
    assert conn.state == :sent
    assert conn.status == 400
    assert Poison.decode!(conn.resp_body) == %{"status" => "Missing 'from' and 'to' fields"}

    assert not called Redix.command!(:_, :_)
  end

  test "get domain [From > To]" do
  conn = 
      :get
      |> conn("/visited_domains?from=5&to=4")
      |> DomainCounter.call(@opts)
  
  assert conn.state == :sent
  assert conn.status == 400
  assert Poison.decode!(conn.resp_body) == %{"status" => "From should be <= than To"}

  assert not called Redix.command!(:_, :_)
  end

  test "get domain [Not integers]" do
    conn = 
        :get
        |> conn("/visited_domains?from=one&to=two")
        |> DomainCounter.call(@opts)
    
  assert conn.state == :sent
  assert conn.status == 400
  assert Poison.decode!(conn.resp_body) == %{"status" => "'from' and 'to' should be integers"}

  assert not called Redix.command!(:_, :_)
  end

end

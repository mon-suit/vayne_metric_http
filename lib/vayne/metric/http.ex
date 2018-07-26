defmodule Vayne.Metric.Http do

  @behaviour Vayne.Task.Metric

  @moduledoc """
  Get Http request metrics
  """

  @doc """
  Params below:

  * `url`: Url to do http request.Required.
  * `method`: Method to do http request. Not required. Default "get".
  * `host`: Host header. Not required.
  * `body`: Body to send http request. Not required.
  * `status_code`: Match status_code. Default 200.
  * `match_str`: Match response body. Not required.


  ## Examples

      iex> Vayne.Metric.Http.init(%{"url" => "http://www.google.com"})
      {:ok, %{"method" => "get", "status_code" => 200, "url" => "http://www.google.com"}}

      iex> Vayne.Metric.Http.init(%{"url" => "www.google.com"})
      {:error, "url format error"}

      iex> Vayne.Metric.Http.init(%{"url" => "http://www.google.com", "method" => "post"})
      {:ok, %{"method" => "post", "status_code" => 200, "url" => "http://www.google.com"}}

      iex> Vayne.Metric.Http.init(%{"url" => "http://www.google.com", "method" => "foo"})
      {:error, "foo not support"}

      iex> Vayne.Metric.Http.init(%{"url" => "http://www.google.com", "status_code" => 301})
      {:ok, %{"method" => "get", "status_code" => 301, "url" => "http://www.google.com"}}

      iex> Vayne.Metric.Http.init(%{"url" => "http://www.google.com", "status_code" => "200"})
      {:error, "status code should be integer"}
  """


  @default_method "get"
  @default_status_code 200

  @url_regex ~r/^https?:\/\//
  @method    ~w(get post delete patch head put)

  def init(params) do
    with {:ok, url} <- get_url(params),
      {:ok, method} <- get_method(params),
      {:ok, status_code} <- get_status_code(params)
    do
      stat = params
        |> Map.take(~w(host body match_str))
        |> Map.put("status_code", status_code)
        |> Map.put("url", url)
        |> Map.put("method", method)

      {:ok, stat}
    else
      {:error, _} = error -> error
    end
  end

  def run(stat, log_func) do

    method = String.to_atom(stat["method"])

    {:ok, worker_pid} = HTTPotion.spawn_link_worker_process(stat["url"])

    opt = [direct: worker_pid]
    opt = if stat["body"], do: Keyword.put(opt, :body, stat["body"]), else: opt
    opt = if stat["host"], do: Keyword.put(opt, :ibrowse, [host_header: stat["host"]]), else: opt

    begin = :erlang.system_time(:milli_seconds)

    #The default timeout is 5000 ms
    response = HTTPotion.request(method, stat["url"], opt)
    using    = :erlang.system_time(:milli_seconds) - begin

    HTTPotion.stop_worker_process(worker_pid)

    ret = case response do
      %{status_code: status, body: body} ->

        if chk_status(stat["status_code"], status)
           && chk_body(stat["match_str"], body)
        do
          %{"http.check" => 1, "http.ms" => using}
        else
          log_func.("http check fail, stat:#{inspect stat}, code:#{status}, body:#{String.length(body)}")
          %{"http.check" => 0, "http.ms" => using}
        end

      error ->
        log_func.("http error, stat:#{inspect stat}, reaseon:#{inspect error}")
        %{"http.check" => 0, "http.ms" => using}
    end

    {:ok, ret}
  end

  def clean(_), do: :ok

  defp chk_status(m_status, status) do
    is_nil(m_status) or m_status == status
  end

  defp chk_body(m_body, body) do
    is_nil(m_body) or String.contains?(body, m_body)
  end

  defp get_status_code(params) do
    code = params["status_code"] || @default_status_code
    if is_integer(code) do
      {:ok, code}
    else
      {:error, "status code should be integer"}
    end
  end

  defp get_method(params) do
    method = String.downcase(params["method"] || @default_method)
    if method in @method do
      {:ok, method}
    else
      {:error, "#{method} not support"}
    end
  end

  defp get_url(params) do
    url = params["url"]
    cond do
      is_nil(url)       -> {:error, "url is needed"}
      url =~ @url_regex -> {:ok, url}
      true              -> {:error, "url format error"}
    end
  end

end

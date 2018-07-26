url = case System.argv do
  [arg] -> arg
  _     -> "http://www.google.com"
end

supervisor = Vayne.Test.TaskSupervisor

Task.Supervisor.start_link(name: supervisor)

Application.ensure_all_started(:httpotion)

params = %{"url" => url}

task = %Vayne.Task{
  uniqe_key:   "normal success",
  interval:    10,
  metric_info: %{module: Vayne.Metric.Http, params: params},
  deal_info:   %{module: Vayne.Export.Console, params: nil}
}

test_func = fn task_count ->
  1..task_count
    |> Enum.map(fn _ ->
      Task.Supervisor.async_nolink(supervisor, fn -> Vayne.Task.test_task(task) end)
    end)
    |> Enum.map(fn task ->
      ret = Task.await(task, :infinity)
      case ret do
        {:ok, %{"http.check" => 1, "http.ms" => ms}} -> {true, ms}
        {:ok, %{"http.check" => 0, "http.ms" => ms}} -> {false, ms}
        _ -> {false, nil}
      end
    end)
    |> Enum.reduce({%{}, []}, fn ({suc, time}, {sta, ms}) ->

      type  = if suc, do: "ok", else: "error"
      count = sta[type] || 0
      sta   = Map.put(sta, type, count+1)
      ms = [time | ms]
      {sta, ms}
    end)
end

max_error = 20
#batch = Enum.map(1..3, &(trunc(:math.pow(10, &1))))
batch = [10, 50, 100, 500, 1000, 1500]

IO.puts "port limit: #{:erlang.system_info(:port_limit)}, url: #{url}, max_error: #{max_error}"

Enum.reduce_while(batch, nil, fn task_count, _acc ->
  {time, {result, ms}} = :timer.tc(fn -> test_func.(task_count) end)

  time   = div(time, 1000)
  all_ms = ms |> Enum.filter(&(not is_nil(&1))) |> Enum.sum
  rps    = div(all_ms, result["ok"])

  IO.puts "task count: #{task_count}, using: #{time}ms, rps: #{rps}ms, result: #{inspect result}"

  if Map.has_key?(result, "error") && result["error"] > max_error, do: {:halt, nil}, else: {:cont, nil}
end)

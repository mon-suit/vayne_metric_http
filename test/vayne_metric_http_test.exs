defmodule VayneMetricHttpTest do
  use ExUnit.Case, async: false
  doctest Vayne.Metric.Http

  @supervisor Vayne.Test.TaskSupervisor

  setup_all do
    :inet_gethost_native.start_link
    Task.Supervisor.start_link(name: @supervisor)
    Process.sleep(2_000)
    :ok
  end

  setup do
    process_count = length(Process.list())
    port_count    = length(Port.list())
    ets_count     = length(:ets.all())
    on_exit "ensure release resource", fn ->
      assert process_count == length(Process.list())
      assert port_count    == length(Port.list())
      assert ets_count     == length(:ets.all())
    end
  end

  test "normal success request" do

    params = %{"url" => "http://httpbin.org/status/200"}

    task = %Vayne.Task{
      uniqe_key:   "normal success",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Http, params: params},
      export_info:   %{module: Vayne.Export.Console, params: nil}
    }

    async = Task.Supervisor.async_nolink(@supervisor, fn ->
      Vayne.Task.test_task(task)
    end)

    {:ok, metrics} = Task.await(async)
    assert metrics["http.check"] == 1
  end

  test "post success request" do
    params = %{
      "url" => "http://httpbin.org/post", "method" => "post",
      "body" => "fffff", "match_str" => "fffff"
    }

    task = %Vayne.Task{
      uniqe_key:   "post success",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Http, params: params},
      export_info:   %{module: Vayne.Export.Console, params: nil}
    }

    async = Task.Supervisor.async_nolink(@supervisor, fn ->
      Vayne.Task.test_task(task)
    end)

    {:ok, metrics} = Task.await(async)
    assert metrics["http.check"] == 1
  end

  test "match code failed" do
    params = %{"url" => "http://httpbin.org/status/302"}

    task = %Vayne.Task{
      uniqe_key:   "normal success",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Http, params: params},
      export_info:   %{module: Vayne.Export.Console, params: nil}
    }

    async = Task.Supervisor.async_nolink(@supervisor, fn ->
      Vayne.Task.test_task(task)
    end)

    {:ok, metrics} = Task.await(async)
    assert metrics["http.check"] == 0
  end

  test "body match failed" do
    params = %{
      "url" => "http://httpbin.org/post", "method" => "post",
      "body" => "fffff", "match_str" => "gggggg"
    }

    task = %Vayne.Task{
      uniqe_key:   "post success",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Http, params: params},
      export_info:   %{module: Vayne.Export.Console, params: nil}
    }

    async = Task.Supervisor.async_nolink(@supervisor, fn ->
      Vayne.Task.test_task(task)
    end)

    {:ok, metrics} = Task.await(async)
    assert metrics["http.check"] == 0

  end

end

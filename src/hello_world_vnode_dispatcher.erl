-module(hello_world_vnode_dispatcher).
-behaviour(gen_server2).

-include("hello_world_vnode_dispatcher.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-export([
  start_link/0,
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

-record(state, { queue, client, tag, channel }).

start_link() ->
  gen_server2:start_link({local, ?MODULE}, ?MODULE, [], [{timeout, infinity}]).

init([]) ->
  process_flag(trap_exit, true),

  AmqpParams = #amqp_params_network {
    username = <<"guest">>,
    password = <<"guest">>,
    virtual_host = <<"/">>,
    host = "127.0.0.1",
    port = 5672
  },
  {ok, Client} = amqp_connection:start(AmqpParams),        
  {ok, Channel} = amqp_connection:open_channel(Client),
  
  % Declare the queue we'll be using for invocations
  #'queue.declare_ok'{ queue = Q } = amqp_channel:call(Channel, #'queue.declare'{ auto_delete = true }),
  
  % Declare the exchange we'll be using for invocations
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, #'exchange.declare'{ exchange = <<"riak-core-dispatcher">>, type = <<"topic">> }),
  
  % Bind this queue to the riak-core exchange
  QB = #'queue.bind'{ 
    queue = Q, 
    exchange = <<"riak-core-dispatcher">>, 
    routing_key = <<"#">> 
  },
  #'queue.bind_ok'{} = amqp_channel:call(Channel, QB),

  % Consume from this queue
  #'basic.consume_ok'{ consumer_tag = Tag } = amqp_channel:subscribe(Channel, #'basic.consume'{ queue = Q }, self()),
  
  {ok, #state {
    queue = Q,
    client = Client,
    tag = Tag,
    channel = Channel
  }}.

handle_call(Msg, From, State) ->
  io:format("handle_call: ~p ~p ~p~n", [Msg, From, State]),
  {noreply, State}.

handle_cast(Msg, State) ->
  io:format("handle_cast: ~p ~p~n", [Msg, State]),
  {noreply, State}.

handle_info(#'basic.cancel_ok'{ consumer_tag = _Tag }, State) ->
  {noreply, State};

handle_info(#'basic.consume_ok'{ consumer_tag = _Tag }, State) ->
  {noreply, State};

handle_info(D = {#'basic.deliver'{ delivery_tag = DeliveryTag }, 
  #amqp_msg { 
    props = #'P_basic'{ 
  		content_type = _ContentType, 
  		headers = Headers0, 
  		reply_to = _ReplyTo
		}, 
		payload = Payload 
	} = Msg }, State = #state{ queue = _Q, client = _Client, tag = _Tag, channel = Channel }) ->
  io:format("headers: ~p~n", [Msg]),
  io:format("delivery: ~p~n", [D]),
  amqp_channel:cast(Channel, #'basic.ack'{ delivery_tag = DeliveryTag }),

  Headers = case Headers0 of
    _ when is_list(Headers0) -> Headers0;
    _ -> []
  end,

  CHash = chash(Headers),
  io:format("chash: ~p~n", [CHash]),
  case riak_core_apl:get_primary_apl(CHash, 1, hello_world) of
    [{Index, _Type}] ->
      case lists:keyfind(?TARGET_VNODE, 1, Headers) of
        {?TARGET_VNODE, _, T} ->
          TargetVNodeMaster = list_to_atom(binary_to_list(T) ++ "_master"),
          %io:format("target vnode: ~p~n", [TargetVNode]),
          {struct, Args} = mochijson2:decode(Payload),
          io:format("sync_spawn_command(~p, ~p, ~p)~n", [Index, Args, TargetVNodeMaster]),
          Reply = riak_core_vnode_master:sync_spawn_command(Index, Args, TargetVNodeMaster),
          io:format("response: ~p~n", [Reply]);
        _ ->
          io:format("No nodes available for that vnode.~n", [])
      end,
      {noreply, State};
    {error, Reason} -> {error, Reason}
  end;

handle_info(Msg, State) ->
  io:format("handle_info: ~p ~p~n", [Msg, State]),
  {noreply, State}.

terminate(Reason, State = #state{ queue = Q, client = _Client, channel = Channel }) ->
  amqp_channel:call(Channel, #'queue.delete'{ queue = Q }),
  io:format("terminate: ~p ~p~n", [Reason, State]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  % io:format("code_change: ~p ~p ~p~n", [OldVsn, State, Extra]),
  {ok, State}.

chash(Headers) when is_list(Headers) ->
  HashKey = case lists:keyfind(?HASH_KEY, 1, Headers) of
    {?HASH_KEY, _, K} -> {?HASH_KEY, K};
    _ -> {?HASH_KEY, term_to_binary(erlang:now())}
  end,
  io:format("hashing on: ~p~n", [HashKey]),
  riak_core_util:chash_key(HashKey);

chash(_) ->
  chash([]).

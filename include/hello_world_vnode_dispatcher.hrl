-ifndef(RABBITMQ_RIAK_CORE_VNODE_DISPATCHER).
-define(RABBITMQ_RIAK_CORE_VNODE_DISPATCHER, ok).

-define(TARGET_VNODE, <<"x-riak-target-vnode">>).
-define(HASH_KEY, <<"x-riak-hash-key">>).
-define(P_BASIC_VNODE(CT, VNode), #'P_basic'{ content_type=CT, headers=[{?TARGET_VNODE, binary, VNode}] }).
-define(VNODE_MASTER(Name, VNode), {Name, {riak_core_vnode_master, start_link, [VNode]}, permanent, 5000, worker, [riak_core_vnode_master]}).
-define(GEN_SERVER(Name, Worker), {Name, {Worker, start_link, []}, permanent, 5000, worker, [Worker]}).

-endif.
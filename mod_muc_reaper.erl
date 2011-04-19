%% Author: sylvain niles
%% Created: Apr 12, 2011
%% Description: Detects peer node in cluster going down and forces all clients to reconnect.
-module(mod_muc_reaper).

-behavior(gen_server).
-behavior(gen_mod).

%%
%% Include files
%%

-include("ejabberd.hrl").
-include("jlib.hrl").

-define(PROCNAME, reaper).


%%
%% Exported Functions
%%

-export([start_link/2, reap_all/0]).

-export([start/2,
         stop/1,
         init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

start_link(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts], []).


start(Host, Opts) ->
       	?INFO_MSG("mod_muc_reaper starting", []),
	Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    	ChildSpec = {Proc,
        {?MODULE, start_link, [Host, Opts]},
        temporary,
        1000,
        worker,
        [?MODULE]},
    	supervisor:start_child(ejabberd_sup, ChildSpec).

stop(Host) ->
       	?INFO_MSG("mod_muc_reaper stopping", []),
    	Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    	gen_server:call(Proc, stop),
    	supervisor:terminate_child(ejabberd_sup, Proc),
    	supervisor:delete_child(ejabberd_sup, Proc).


init([Host, _Opts]) ->
%% Monitor all connected erlang nodes
	net_kernel:monitor_nodes(true),
{ok, Host}.



handle_call(stop, _From, Host) ->
    {stop, normal, ok, Host}.

handle_cast(_Msg, Host) ->
    {noreply, Host}.

handle_info(Msg, Host) ->
	case Msg of 
		{nodedown, _} ->
			reap_all(),
			{noreply, Host};
		_ ->
			{noreply, Host}
	end.

terminate(_Reason, _Host) ->
    ok.

code_change(_OldVsn, Host, _Extra) ->
    {ok, Host}.

%%
%% Local Functions
%%

reap_all() ->
	AllSessions = ejabberd_sm:dirty_get_sessions_list(),
	reap_all(AllSessions).

reap_all(Sessions) ->
	error_logger:error_report(Sessions),
	lists:foreach(
		fun({U, S, R}) ->
			JID = {U, S, R},
			error_logger:error_report(JID),
			SID = ejabberd_sm:get_session_pid(U, S, R),
			%%ejabberd_sm:close_session(SID, U, S, R)
			SID ! disconnect
		end, Sessions).
		

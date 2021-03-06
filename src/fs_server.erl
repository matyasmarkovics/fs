-module(fs_server).
-behaviour(gen_server).
-define(SERVER, ?MODULE).
-export([start_link/6]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).

-record(state, {event_handler, port, path, backend}).

notify(EventHandler, file_event = A, Msg) -> Key = {fs, A}, gen_event:notify(EventHandler, {self(), Key, Msg}).
start_link(Name, EventHandler, Backend, Path, Cwd, Events) -> gen_server:start_link({local, Name}, ?MODULE, [EventHandler, Backend, Path, Cwd, Events], []).
init([EventHandler, Backend, Path, Cwd, Events]) -> {ok, #state{event_handler=EventHandler,port=Backend:start_port(Path, Cwd, Events),path=Path,backend=Backend}}.

handle_call(known_events, _From, #state{backend=Backend} = State) -> {reply, Backend:known_events(), State};
handle_call(_Request, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info({_Port, {data, {eol, Line}}}, #state{event_handler=EventHandler,backend=Backend} = State) ->
    Event = Backend:line_to_event(Line),
    notify(EventHandler, file_event, Event),
    {noreply, State};
handle_info({_Port, {data, {noeol, Line}}}, State) ->
    error_logger:error_msg("~p line too long: ~p, ignoring~n", [?SERVER, Line]),
    {noreply, State};
handle_info({_Port, {exit_status, Status}}, State) -> {stop, {port_exit, Status}, State};
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, #state{port=Port}) -> (catch port_close(Port)), ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.

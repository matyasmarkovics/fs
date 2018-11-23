-module(inotifywait).
-include("include/api.hrl").
-export(?API).
-define(OPTIONS,
        [{created, "CREATE"},
         {deleted, "DELETE"},
         {isdir, "ISDIR"},
         {modified, "MODIFY"},
         {modified, "CLOSE_WRITE"},
         {closed, "CLOSE"},
         {renamed, "MOVED_TO"},
         {attribute, "ATTRIB"}]).

find_executable() -> os:find_executable("inotifywait").
known_events() -> proplists:get_keys(?OPTIONS).

start_port(Path, Cwd, Events) ->
    Path1 = filename:absname(Path),
    EventArgs = [ [Option, string:lowercase(EventFlag)]
                  || Event <- Events,
                     is_atom(Event),
                     EventFlag <- convert_flag(Event),
                     Option <- ["-e"] ],
    Args = ["-c", "inotifywait $0 $@ & PID=$!; read a; kill $PID",
            "-m", "--quiet", "-r"] ++ EventArgs ++ [Path1],
    erlang:open_port({spawn_executable, os:find_executable("sh")},
        [stream, exit_status, {line, 16384}, {args, Args}, {cd, Cwd}]).

line_to_event(Line) ->
    {match, [Dir, Flags1, DirEntry]} = re:run(Line, re(), [{capture, all_but_first, list}]),
    Flags = [ E
              || F <- string:tokens(Flags1, ","),
                 E <- convert_flag(F) ],
    Path = Dir ++ DirEntry,
    {Path, Flags}.

convert_flag(Flag) when is_list(Flag) -> proplists:get_all_values(Flag, pl_rev(?OPTIONS));
convert_flag(Flag) when is_atom(Flag) -> proplists:get_all_values(Flag, ?OPTIONS).

re() ->
    case get(inotifywait_re) of
        undefined ->
            {ok, R} = re:compile("^(.*/) ([A-Z_,]+) (.*)$", [unicode]),
            put(inotifywait_re, R),
            R;
        V -> V
    end.

pl_rev(PList) ->
    {Keys, Vals}
    = lists:unzip(
        [ {Key, Val}
          || Key <- proplists:get_keys(PList),
             All <- proplists:get_all_values(Key, PList),
             Val <- All ]),
    lists:zip(Vals, Keys).

"""Selector, filtering, targeting, and safety contracts for moving workspaces between sessions."""
import importlib.util
from pathlib import Path
import sys
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN / 'scripts'))
spec = importlib.util.spec_from_file_location('move', PLUGIN / 'scripts/move.py')
move = importlib.util.module_from_spec(spec)
spec.loader.exec_module(move)


def pane(pane_id, tool='shell'):
    return {'type': 'pane', 'slot': 1, 'pane_id': pane_id, 'tool': tool, 'command': None,
            'cwd': '~/src', 'session_id': None, 'note': ''}


def tab(tab_id, label, layout):
    return {'tab_id': tab_id, 'label': label, 'number': 1, 'zoomed': False,
            'focused_pane_id': None, 'layout': layout}


ALPHA = {'workspace_id': 'w1', 'label': 'alpha', 'number': 1, 'active_tab_id': 'w1:t1',
         'tabs': [tab('w1:t1', 'main', pane('w1:p1', 'claude'))]}
BETA_SPLIT = {'type': 'split', 'direction': 'right', 'ratio': 0.5,
              'children': [pane('w2:p1', 'claude'), pane('w2:p2', 'codex')]}
BETA = {'workspace_id': 'w2', 'label': 'beta', 'number': 2, 'active_tab_id': 'w2:t1',
        'tabs': [tab('w2:t1', 'agents', BETA_SPLIT), tab('w2:t2', 'dev', pane('w2:p3'))]}
SLASHED = {'workspace_id': 'w3', 'label': 'gamma/delta', 'number': 3, 'active_tab_id': 'w3:t1',
           'tabs': [tab('w3:t1', 'main', pane('w3:p1'))]}


def state(focus=None):
    return {'schema': 'resume-after-reboot/v2', 'captured': '2026-01-01T00:00:00+00:00',
            'backend': 'herdr', 'session': 'default',
            'focus': focus or {'workspace_id': 'w9', 'tab_id': 'w9:t1', 'pane_id': 'w9:p1'},
            'workspaces': [ALPHA, BETA, SLASHED]}


class SelectWorkspaces(unittest.TestCase):
    def test_workspace_label_selects_the_whole_workspace(self):
        filtered, closes = move.filter_state(state(), ['beta'], 'later')
        self.assertEqual(
            (filtered, closes),
            ({'schema': 'resume-after-reboot/v2', 'captured': '2026-01-01T00:00:00+00:00',
              'backend': 'herdr', 'session': 'later', 'focus': {}, 'workspaces': [BETA]},
             [('workspace', 'w2')]))

    def test_workspace_slash_tab_wraps_the_tab_as_its_own_workspace(self):
        filtered, closes = move.filter_state(state(), ['beta/dev'], 'later')
        self.assertEqual(
            (filtered['workspaces'], closes),
            ([{'workspace_id': 'w2:t2', 'label': 'dev', 'number': 1, 'active_tab_id': 'w2:t2',
               'from_workspace': 'beta', 'tabs': [BETA['tabs'][1]]}],
             [('tab', 'w2:t2')]))

    def test_selections_keep_source_order_and_whole_workspace_absorbs_its_tabs(self):
        _, closes = move.filter_state(state(), ['beta/dev', 'alpha', 'beta'], 'later')
        self.assertEqual(closes, [('workspace', 'w1'), ('workspace', 'w2')])

    def test_label_containing_slash_matches_the_workspace_first(self):
        filtered, closes = move.filter_state(state(), ['gamma/delta'], 'later')
        self.assertEqual((filtered['workspaces'], closes), ([SLASHED], [('workspace', 'w3')]))

    def test_unknown_workspace_names_the_choices(self):
        with self.assertRaises(move.MoveError) as caught:
            move.filter_state(state(), ['zeta'], 'later')
        self.assertEqual(str(caught.exception),
                         'no workspace or workspace/tab matches "zeta"; '
                         'workspaces: alpha, beta, gamma/delta')

    def test_unknown_tab_names_the_workspace_tabs(self):
        with self.assertRaises(move.MoveError) as caught:
            move.filter_state(state(), ['beta/nope'], 'later')
        self.assertEqual(str(caught.exception),
                         'no workspace or workspace/tab matches "beta/nope"; '
                         'workspaces: alpha, beta, gamma/delta')

    def test_ambiguous_workspace_label_is_refused(self):
        twin = {**ALPHA, 'workspace_id': 'w5'}
        doubled = {**state(), 'workspaces': [ALPHA, twin]}
        with self.assertRaises(move.MoveError) as caught:
            move.filter_state(doubled, ['alpha'], 'later')
        self.assertEqual(str(caught.exception), '"alpha" matches 2 workspaces; rename one first')


class FilteredFocus(unittest.TestCase):
    def test_focus_is_empty_when_the_focused_workspace_stays_behind(self):
        filtered, _ = move.filter_state(state(), ['alpha'], 'later')
        self.assertEqual(filtered['focus'], {})

    def test_focus_is_kept_when_the_focused_workspace_moves(self):
        focus = {'workspace_id': 'w2', 'tab_id': 'w2:t1', 'pane_id': 'w2:p1'}
        filtered, _ = move.filter_state(state(focus), ['beta'], 'later')
        self.assertEqual(filtered['focus'], focus)

    def test_focus_follows_a_moved_tab_into_its_wrapper_workspace(self):
        focus = {'workspace_id': 'w2', 'tab_id': 'w2:t2', 'pane_id': 'w2:p3'}
        filtered, _ = move.filter_state(state(focus), ['beta/dev'], 'later')
        self.assertEqual(filtered['focus'],
                         {'workspace_id': 'w2:t2', 'tab_id': 'w2:t2', 'pane_id': 'w2:p3'})

    def test_focus_is_empty_when_a_sibling_tab_moves(self):
        focus = {'workspace_id': 'w2', 'tab_id': 'w2:t1', 'pane_id': 'w2:p1'}
        filtered, _ = move.filter_state(state(focus), ['beta/dev'], 'later')
        self.assertEqual(filtered['focus'], {})


class TargetEnv(unittest.TestCase):
    def test_strips_pane_bindings_and_names_the_session(self):
        environ = {'PATH': '/bin', 'HERDR_SOCKET_PATH': '/s.sock', 'HERDR_CLIENT_SOCKET_PATH': '/c',
                   'HERDR_WORKSPACE_ID': 'w1', 'HERDR_TAB_ID': 'w1:t1', 'HERDR_PANE_ID': 'w1:p1',
                   'HERDR_SESSION': 'old', 'HERDR_BIN_PATH': '/opt/herdr'}
        self.assertEqual(move.session_env('later', environ),
                         {'PATH': '/bin', 'HERDR_SESSION': 'later', 'HERDR_BIN_PATH': '/opt/herdr'})

    def test_does_not_mutate_the_given_environment(self):
        environ = {'HERDR_PANE_ID': 'w1:p1'}
        move.session_env('later', environ)
        self.assertEqual(environ, {'HERDR_PANE_ID': 'w1:p1'})


SESSION_LIST = """name                 status   directory                    socket
default              running  /h/.config/herdr             /h/.config/herdr/herdr.sock
later                running  /h/.config/herdr/sessions/later /h/.config/herdr/sessions/later/herdr.sock
"""


class CallerSession(unittest.TestCase):
    def test_socket_path_identifies_the_session(self):
        environ = {'HERDR_SOCKET_PATH': '/h/.config/herdr/sessions/later/herdr.sock'}
        self.assertEqual(move.caller_session(environ, SESSION_LIST), 'later')

    def test_falls_back_to_herdr_session(self):
        self.assertEqual(move.caller_session({'HERDR_SESSION': 'later'}, SESSION_LIST), 'later')

    def test_defaults_to_default(self):
        self.assertEqual(move.caller_session({}, SESSION_LIST), 'default')


class RunningSessions(unittest.TestCase):
    LIST = SESSION_LIST + 'demo                 stopped  /h/.config/herdr/sessions/demo /h/.config/herdr/sessions/demo/herdr.sock\n'

    def test_lists_running_sessions_in_order_and_skips_stopped(self):
        self.assertEqual(move.snapshot.running_sessions(self.LIST), ['default', 'later'])

    def test_header_alone_has_no_running_sessions(self):
        self.assertEqual(move.snapshot.running_sessions('name status directory socket\n'), [])


class ServerState(unittest.TestCase):
    def test_reads_server_not_running(self):
        stdout = ('{"id":"cli:api:snapshot","error":{"code":"server_not_running",'
                  '"message":"no herdr server is running"}}')
        self.assertEqual(move.error_code(stdout), 'server_not_running')

    def test_success_has_no_error_code(self):
        self.assertEqual(move.error_code('{"id":"cli","result":{"snapshot":{}}}'), None)

    def test_unparseable_output_has_no_error_code(self):
        self.assertEqual(move.error_code('not json'), None)


class Safety(unittest.TestCase):
    STATUSES = {'w2:p1': 'working', 'w2:p2': 'blocked', 'w2:p3': 'idle', 'w1:p1': 'done'}

    def test_working_pane_refuses_the_move(self):
        filtered, _ = move.filter_state(state(), ['alpha', 'beta'], 'later')
        with self.assertRaises(move.MoveError) as caught:
            move.check_safety(filtered, self.STATUSES, caller_pane=None)
        self.assertEqual(str(caught.exception),
                         'refusing to move panes that are working (closing them interrupts the turn):\n'
                         '  beta / agents  pane w2:p1  claude')

    def test_blocked_pane_is_a_warning(self):
        filtered, _ = move.filter_state(state(), ['alpha', 'beta/dev'], 'later')
        statuses = {**self.STATUSES, 'w1:p1': 'blocked'}
        self.assertEqual(move.check_safety(filtered, statuses, caller_pane=None),
                         ['alpha / main  pane w1:p1  claude is blocked; its pending prompt will be dropped'])

    def test_moved_tab_is_reported_under_its_source_workspace(self):
        filtered, _ = move.filter_state(state(), ['beta/agents'], 'later')
        with self.assertRaises(move.MoveError) as caught:
            move.check_safety(filtered, self.STATUSES, caller_pane=None)
        self.assertEqual(str(caught.exception),
                         'refusing to move panes that are working (closing them interrupts the turn):\n'
                         '  beta / agents  pane w2:p1  claude')

    def test_clear_selection_has_no_warnings(self):
        filtered, _ = move.filter_state(state(), ['beta/dev'], 'later')
        self.assertEqual(move.check_safety(filtered, self.STATUSES, caller_pane=None), [])

    def test_caller_pane_refuses_the_move(self):
        filtered, _ = move.filter_state(state(), ['beta/dev'], 'later')
        with self.assertRaises(move.MoveError) as caught:
            move.check_safety(filtered, self.STATUSES, caller_pane='w2:p3')
        self.assertEqual(str(caught.exception),
                         'refusing to move pane w2:p3: it is running this command; '
                         'run the move from a pane outside the selection')


class Summary(unittest.TestCase):
    def test_counts_moved_panes_by_tool_and_status(self):
        snap = {'panes': [
            {'pane_id': 'n1:p1', 'workspace_id': 'n1', 'agent': 'claude', 'agent_status': 'idle'},
            {'pane_id': 'n1:p2', 'workspace_id': 'n1', 'agent': 'claude', 'agent_status': 'idle'},
            {'pane_id': 'n1:p3', 'workspace_id': 'n1', 'agent': 'codex', 'agent_status': 'unknown'},
            {'pane_id': 'n2:p1', 'workspace_id': 'n2', 'agent_status': 'unknown'},
            {'pane_id': 'x1:p1', 'workspace_id': 'x1', 'agent': 'claude', 'agent_status': 'working'},
        ]}
        self.assertEqual(move.summarize(snap, {'n1', 'n2'}),
                         {('claude', 'idle'): 2, ('codex', 'unknown'): 1, ('shell', 'unknown'): 1})


if __name__ == '__main__':
    unittest.main()

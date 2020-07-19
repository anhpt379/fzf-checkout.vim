function! fzf_checkout#get_ref(line)
  " Get first column.
  return split(a:line)[0]
endfunction


function! s:checkout(lines)
  if len(a:lines) < 2
    return
  endif

  let l:query = a:lines[0]
  let l:key = a:lines[1]

  if l:key ==# g:fzf_checkout_create_key
    let l:branch = l:query
  elseif len(a:lines) > 2
    let l:branch = fzf_checkout#get_ref(a:lines[2])
  else
    return
  endif

  let l:branch = shellescape(l:branch)

  if l:key ==# g:fzf_checkout_track_key
    " Track remote branch
    let l:execute_options = {
          \ 'terminal': 'split | terminal {git} checkout --track {branch}',
          \ 'system': 'echo system("{git} checkout --track {branch}")',
          \ 'bang': '!{git} checkout --track {branch}',
          \}
    let l:execute_command = get(
          \ l:execute_options,
          \ g:fzf_checkout_track_execute,
          \ g:fzf_checkout_track_execute,
          \)
  elseif l:key ==# g:fzf_checkout_create_key
    " Create branch
    let l:execute_options = {
          \ 'terminal': 'split | terminal {git} checkout -b {branch}',
          \ 'system': 'echo system("{git} checkout -b {branch}")',
          \ 'bang': '!{git} checkout -b {branch}',
          \}
    let l:execute_command = get(
          \ l:execute_options,
          \ g:fzf_checkout_create_execute,
          \ g:fzf_checkout_create_execute,
          \)
  elseif l:key ==# g:fzf_checkout_delete_key
    " Create branch
    let l:execute_options = {
          \ 'terminal': 'split | terminal {git} branch -d {branch}',
          \ 'system': 'echo system("{git} branch -d {branch}")',
          \ 'bang': '!{git} branch -d {branch}',
          \}
    let l:execute_command = get(
          \ l:execute_options,
          \ g:fzf_checkout_delete_execute,
          \ g:fzf_checkout_delete_execute,
          \)
  else
    " Normal checkout
    let l:execute_options = {
          \ 'terminal': 'split | terminal {git} checkout {branch}',
          \ 'system': 'echo system("{git} checkout {branch}")',
          \ 'bang': '!{git} checkout {branch}',
          \}
    let l:execute_command = get(
          \ l:execute_options,
          \ g:fzf_checkout_execute,
          \ g:fzf_checkout_execute,
          \)
  endif

  let l:execute_command = substitute(l:execute_command, '{git}', g:fzf_checkout_git_bin, 'g')
  let l:execute_command = substitute(l:execute_command, '{branch}', l:branch, 'g')
  execute l:execute_command
endfunction


function! s:get_current_ref()
  " Try to get the branch name or fallback to get the commit.
  let l:current = system('git symbolic-ref --short -q HEAD || git rev-parse --short HEAD')
  let l:current = substitute(l:current, '\n', '', 'g')
  return l:current
endfunction


function! s:get_previous_ref()
  " Try to get the branch name or fallback to get the commit.
  let l:previous = system('git rev-parse -q --abbrev-ref --symbolic-full-name "@{-1}"')
  if l:previous =~# '^\s*$' || l:previous =~# "'@{-1}'"
    let l:previous = system('git rev-parse --short -q "@{-1}"')
  endif
  let l:previous = substitute(l:previous, '\n', '', 'g')
  return l:previous
endfunction


function! fzf_checkout#list(bang, type)
  let l:current = s:get_current_ref()
  let l:current_escaped = escape(l:current, '/')

  let l:previous = s:get_previous_ref()
  let l:previous_escaped = escape(l:previous, '/')

  let l:valid_keys = join([g:fzf_checkout_track_key, g:fzf_checkout_create_key, g:fzf_checkout_delete_key], ',')

  " See valid atoms in
  " https://github.com/git/git/blob/076cbdcd739aeb33c1be87b73aebae5e43d7bcc5/ref-filter.c#L474
  let l:format =
        \ '%(color:yellow bold)%(refname:short)  ' ..
        \ '%(color:reset)%(color:green)%(subject) ' ..
        \ '%(color:reset)%(color:green dim italic)%(committerdate:relative) ' ..
        \ '%(color:reset)%(color:blue)-> %(objectname:short)'

  if a:type ==# 'branch'
    let l:subcommand = 'branch'
    let l:name = 'GCheckout'
  else
    let l:subcommand = 'tag'
    let l:name = 'GCheckoutTag'
  endif
  let l:git_cmd =
        \ g:fzf_checkout_git_bin .. ' ' ..
        \ l:subcommand ..
        \ ' --color=always --sort=refname:short --format=' .. shellescape(l:format) .. ' ' ..
        \ g:fzf_checkout_git_options

  " Filter to delete the current/previous ref, and HEAD from the list.
  let l:color_seq = '\x1b\[1;33m'  " \x1b[1;33mbranch/name
  let l:filter =
        \ 'sed -E ' ..
        \ '-e "/^' .. l:color_seq .. l:current_escaped .. '\s.*$/d" ' ..
        \ '-e "/^' .. l:color_seq .. l:previous_escaped .. '\s.*$/d" ' ..
        \ '-e "/^' .. l:color_seq .. '(origin\/HEAD)|(HEAD)/d"'

  if !empty(l:previous)
    let l:previous = l:git_cmd .. ' --list ' .. l:previous
  endif

  " Put the previous ref first,
  " list everything else,
  " remove empty lines.
  let l:source =
        \ 'printf "$(' .. l:previous  .. ')"\\n' ..
        \ '"$(' .. l:git_cmd .. ' | ' .. l:filter .. ')" | ' ..
        \ ' sed "/^\s*$/d"'
  let l:options = [
        \ '--prompt', 'Checkout> ',
        \ '--header', 'On branch '.l:current.', '.toupper(g:fzf_checkout_delete_key).' to delete, '.toupper(g:fzf_checkout_create_key).' to create new',
        \ '--nth', '1',
        \ '--expect', l:valid_keys,
        \ '--ansi',
        \ '--exact',
        \ '--print-query',
        \]
  call fzf#run(fzf#wrap(
        \ l:name,
        \ {
        \   'source': l:source,
        \   'sink*': function('s:checkout'),
        \   'options': l:options,
        \ },
        \ a:bang,
        \))
endfunction

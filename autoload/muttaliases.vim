function! muttaliases#SetMuttAliasesFile() abort
  if !exists('g:muttaliases_file')
    if executable('mutt')
      let output = split(system('mutt -Q "alias_file"'), '\n')

      for line in output
        let alias_file = matchlist(line,'\v^\s*' . 'alias_file' . '\s*\=\s*[''"]?([^''"]*)[''"]?$')
        if !empty(alias_file)
          let g:muttaliases_file = resolve(expand(alias_file[1]))
        else
          let g:muttaliases_file = ''
        endif
      endfor
    elseif filereadable(expand('~/.muttrc'))
      " pedestrian's way
      let muttrc = readfile(expand('~/.muttrc'))

      for line in muttrc
        let alias_file = matchlist(line,'\v^\s*set\s+' . 'alias_file' . '\s*\=\s*[''"]?([^''"]*)[''"]?$')
        if !empty(alias_file)
          let g:muttaliases_file = resolve(expand(alias_file[1]))
        else
          let g:muttaliases_file = ''
        endif
      endfor
    else
      let g:muttaliases_file = ''
    endif
  endif
  if !filereadable(g:muttaliases_file)
    echoerr 'The file ' . g:muttaliases_file . ' is no valid mutt aliases file.'
    echoerr 'Please set $alias_file in ~/.muttrc or g:muttaliases_file in ~/.vimrc to a mutt aliases file!'
    let g:muttaliases_file = ''
  endif
endfunction

function! muttaliases#EditMuttAliasesFile() abort
  if !empty(g:muttaliases_file)
    exe 'edit ' . escape(g:muttaliases_file, ' %#|"')
  else
    echoerr 'The file ' . g:muttaliases_file . ' is no valid mutt aliases file.'
    echoerr 'Please set $alias_file in ~/.muttrc or g:muttaliases_file in ~/.vimrc to a mutt aliases file!'
  endif
endfunction

function! muttaliases#CompleteMuttAliases(findstart, base) abort
  if a:findstart
    " locate the start of the word
    " we stop when we encounter space character
    let col = col('.')-1
    let text_before_cursor = getline('.')[0 : col - 1]
    " let start = match(text_before_cursor, '\v<([[:digit:][:lower:][:upper:]]+[._%+-@]?)+$')
    let start = match(text_before_cursor, '\v<\S+$')
    return start
  else
    let file = g:muttaliases_file

    if empty(file)
      return []
    endif

    " build vim regex to sort according to whether pattern matches at
    " beginning or after delimiter
    let before = '\v^[^@]*'
    let base   = '\V' . escape(a:base, '\')
    let after  = '\v[^@]*($|[@])'

    let pattern       = before . base . after
    let pattern_delim = before . '\v(^|\A)' . base . after
    let pattern_begin = '\v^' . base . after

    let results = [ [], [], [], [], [], [], [] ]

    for line in readfile(file)
      if empty(line)
        continue
      endif
      " remove optional group parameters
      let line = substitute(line, '\v(\s+-group\s+\S+)+', '','')
      let words = split(line)
      if words[0] is# 'alias' && len(words) >= 3
        let name = words[1]
        if name =~? pattern
          " get the alias part
          " mutt uses \ to escape ", we need to remove it!
          let address = substitute(join(words[2:-1], ' '), '\\', '', 'g')
          let address = substitute(address, '\v([^\\])#.*$', '\1', '')
          let dict = {}
          let dict['word'] = address
          let dict['abbr'] = name
          let dict['menu'] = address

          " weigh according to whether pattern matches at
          " beginning or after some delimiter in name or address
          let pertinence = 0
          if name =~? pattern
            let pertinence += 1
            if    name =~? pattern_delim
              let pertinence += 1
              if  name =~? pattern_begin
                let pertinence += 1
              endif
            endif
          endif
          if address =~? pattern
            let pertinence += 1
            if    address =~? pattern_delim
              let pertinence += 1
              if  address =~? pattern_begin
                let pertinence += 1
              endif
            endif
          endif
        call add(results[pertinence], dict)
        endif
      endif
    endfor
    let results = uniq(sort(results[6], 1) +
          \ sort(results[5], 1) + sort(results[4], 1) + sort(results[3], 1) +
          \ sort(results[2], 1) + sort(results[1], 1) + sort(results[0], 1),
          \ 1)
    return results
  endif
endfunction


if !executable('ctags')
    finish
endif

function! s:additional_tag_info() abort
    let tag = GetCurrentTag()
    if tag == {}
        return ''
    endif
    return ' <'..s:tag_info(tag)..'>'
endfunction
let g:ctrl_g_format ..= '%s'
let g:ctrl_g_args += [get(function('s:additional_tag_info'), 'name')..'()']

function! GetCurrentTag() abort
    let language = get(s:file_type_2_language, &filetype, '')
    if language == ''
        return {}
    endif
    let cur_line = line('.')
    for tag in s:get_tags(language)
        if tag.line_start <= cur_line && tag.line_end >= cur_line
            return tag
        endif
    endfor
    return {}
endfunction

augroup __bracketsjump__
    autocmd!
    autocmd BufEnter,BufWrite * call s:setup()
augroup END

let s:file_type_2_language = {}
let s:bufnr_2_cache = {}

function! s:setup() abort
    if expand('%') == ''
        return
    endif
    if has_key(s:file_type_2_language, &filetype)
        return
    endif
    let language = matchstr(system('ctags --print-language '..shellescape(expand('%'))),': \zs[^ ]\+\ze\n$')
    if language == 'NONE'
        let language = ''
    endif
    let s:file_type_2_language[&filetype] = language
    if language != ''
        call s:init(language)
        execute 'augroup __bracketsjump_'..&filetype..'__'
            autocmd!
            execute 'autocmd FileType '..&filetype..' call s:init('..string(language)..')'
        augroup END
    endif
endfunction

function! s:init(language) abort
    execute 'nnoremap <buffer> <silent> [[ :<C-U>call <SID>ll_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'onoremap <buffer> <silent> [[ :<C-U>call <SID>ll_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'vnoremap <buffer> <silent> [[ :<C-U>call <SID>ll_brackets_jump(v:true, '..string(a:language)..', v:count)<CR>'
    execute 'nnoremap <buffer> <silent> ]] :<C-U>call <SID>rr_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'onoremap <buffer> <silent> ]] :<C-U>call <SID>rr_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'vnoremap <buffer> <silent> ]] :<C-U>call <SID>rr_brackets_jump(v:true, '..string(a:language)..', v:count)<CR>'
    execute 'nnoremap <buffer> <silent> [] :<C-U>call <SID>lr_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'onoremap <buffer> <silent> [] :<C-U>call <SID>lr_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'vnoremap <buffer> <silent> [] :<C-U>call <SID>lr_brackets_jump(v:true, '..string(a:language)..', v:count)<CR>'
    execute 'nnoremap <buffer> <silent> ][ :<C-U>call <SID>rl_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'onoremap <buffer> <silent> ][ :<C-U>call <SID>rl_brackets_jump(v:false, '..string(a:language)..', v:count)<CR>'
    execute 'vnoremap <buffer> <silent> ][ :<C-U>call <SID>rl_brackets_jump(v:true, '..string(a:language)..', v:count)<CR>'
endfunction

function! s:ll_brackets_jump(visual_mode, language, num_times) abort
    call s:brackets_jump(a:visual_mode, a:language, {tag -> tag.line_start}, {line1, line2 -> line1 < line2}, a:num_times)
endfunction

function! s:rr_brackets_jump(visual_mode, language, num_times) abort
    call s:brackets_jump(a:visual_mode, a:language, {tag -> tag.line_start}, {line1, line2 -> line1 > line2}, a:num_times)
endfunction

function! s:lr_brackets_jump(visual_mode, language, num_times) abort
    call s:brackets_jump(a:visual_mode, a:language, {tag -> tag.line_end}, {line1, line2 -> line1 < line2}, a:num_times)
endfunction

function! s:rl_brackets_jump(visual_mode, language, num_times) abort
    call s:brackets_jump(a:visual_mode, a:language, {tag -> tag.line_end}, {line1, line2 -> line1 > line2}, a:num_times)
endfunction

function! s:brackets_jump(visual_mode, language, choose_line, compare_line, num_times) abort
    if a:visual_mode
        normal! gv
        let line1 = line("'<")
        let line2 = line("'>")
        if line1 == line('v')
            let cur_line = line2
        else
            let cur_line = line1
        endif
    else
        let cur_line = line('.')
    endif
    let line = cur_line
    let i = 0
    let n = a:num_times < 1 ? 1 : a:num_times
    while i < n
        let nearest_tag = s:get_nearest_tag(a:language, a:choose_line, a:compare_line, line)
        if nearest_tag == {}
            break
        endif
        let line = a:choose_line(nearest_tag)
        let i += 1
    endwhile
    if line != cur_line
        execute printf('normal! %dG0', line)
        call search('\V\C\<'..(nearest_tag.name)..'\>', 'c', line)
        redraw | echo s:tag_info(nearest_tag)
    endif
endfunction

function! s:get_nearest_tag(language, choose_line, compare_line, cur_line) abort
    let nearest_tag = {}
    for tag in s:get_tags(a:language)
        if !a:compare_line(a:choose_line(tag), a:cur_line)
            continue
        endif
        if nearest_tag == {} || a:compare_line(a:choose_line(nearest_tag), a:choose_line(tag))
            let nearest_tag = tag
        endif
    endfor
    return nearest_tag
endfunction

function! s:get_tags(language) abort
    let bufnr = bufnr()
    if has_key(s:bufnr_2_cache, bufnr)
        let cache = s:bufnr_2_cache[bufnr]
        let cache_hit = v:true
    else
        let cache = {}
        let s:bufnr_2_cache[bufnr] = cache
        let cache_hit = v:false
    endif
    let changed_tick = get(b:, 'changedtick', 0)
    if !cache_hit || cache.changed_tick != changed_tick
        let cache.tags = s:do_get_tags(a:language)
        let cache.changed_tick = changed_tick
    endif
    if cache_hit
        call timer_stop(cache.timer_id)
    endif
    let cache.timer_id = timer_start(30*1000, {timer_id -> s:purge_cache(timer_id, bufnr)})
    return cache.tags
endfunction

function! s:purge_cache(timer_id, bufnr) abort
    let cache = s:bufnr_2_cache[a:bufnr]
    if a:timer_id != cache.timer_id
        return
    endif
    call remove(s:bufnr_2_cache, a:bufnr)
endfunction

function! s:do_get_tags(language) abort
    let command_prefix = 'ctags --language-force='..a:language..' -x --_xformat=''%N,%K,%n,%e,%s'' '
    let file_name = expand('%')
    if filereadable(file_name) && &modified == 0
        let results = systemlist(command_prefix.shellescape(file_name))
    else
        let temp_file_name = tempname()
        try
            call writefile(getline(1, '$'), temp_file_name)
            let results = systemlist(command_prefix.shellescape(temp_file_name))
        finally
            call delete(temp_file_name)
        endtry
    endif

    let tags = []
    for result in results
        let parts = split(result, ',', v:true)
        let name = parts[0]
        let kind = parts[1]
        let line_start = str2nr(parts[2])
        if parts[3] == ''
            continue
        endif
        let line_end = str2nr(parts[3])
        "if line_start == line_end
        "    continue
        "endif
        let struct_name = parts[4]
        let tag = {
        \    'name': name,
        \    'kind': kind,
        \    'line_start': line_start,
        \    'line_end': line_end,
        \    'struct_name': struct_name,
        \}
        call add(tags, tag)
    endfor
    call sort(tags, {x, y -> (x.line_end - x.line_start) - (y.line_end - y.line_start)})
    return tags
endfunction

function! s:tag_info(tag) abort
    let tag_info = a:tag.kind..' '
    if a:tag.struct_name != ''
        let tag_info ..= a:tag.struct_name..'.'
    endif
    let tag_info ..= a:tag.name
    return tag_info
endfunction


" File:		C_from_D.vim
" Author:	Renlin Li
" Version:	0.10
" Description:	Generate a simple ChangeLog template from a diff file.
" Usage:	Set those three variables in your .vimrc
" 		let g:CLauthor="your name"
" 		let g:CLemail="your email"
" 		:GenCL root_path_of_the_repo
"
" I have those user-defined commands in .vimrc to make me lazier.
" You can also map them to shortcuts.
"
"command -narg=0 GenCLBin execute 'GenCL /work/oban-work/src/binutils-gdb'
"command -narg=0 GenCLGcc execute 'GenCL /work/oban-work/src/gcc'
"command -narg=0 GenCLGlibc execute 'GenCL /work/oban-work/src/glibc'
"
"Note, your vim wildignore should not have ChangeLog, otherwise vim won't find
"it.

if exists('loaded_genCL')
    finish
endif
let loaded_genCL = 1

if !exists(':genCL')
    command -nargs=1 GenCL call s:ScanPatch(<f-args>)
endif

" get the relative path of a ChangeLog file
fun! s:GetPath(name)
  let tmp = a:name
  let path = s:root
  let tmp = fnamemodify (tmp, ':p:h')
  let tmp = substitute (tmp, path, '', '')

  if tmp == ''
    return '\.'
  else
    return tmp[1:]
  endif

endfun

" build a list of changelog file path
fun! s:ScanPath(rootPath)
  let s:root = expand (a:rootPath)
  if !isdirectory (s:root)
    echoh ErrorMsg | echo s:root " dosen't exit, please check!" | echoh None
    return 0
  endif

  let s:pathList= split(globpath(s:root, '**/ChangeLog'), '\n')
  if (len (s:pathList) == 0)
    echoh ErrorMsg | echo "No ChangeLog found in ".s:root.", or ChangeLog is
	  \ ignored by vim. Please check!" | echoh None
    return 0
  endif

  call map (s:pathList, 's:GetPath(v:val)')
  return 1
endfun

" find the changelog for a changed file
fun! s:FindCL(file)
  let tmp = fnamemodify (a:file, ':h')

  let path = tmp
  while 1
    let num = filter(deepcopy (s:pathList), 'v:val =~ "^'.path.'$"')

    if (len (num) == 1)
      return num[0]
    elseif (path == "\.")
      return '\.'
    endif

    let path = fnamemodify(path, ':h')
  endwhile

  echoh ErrorMsg | echo "No ChangeLog can be found for" . a:file . ", please
	\ check" | echoh None
  return ''
endfun

" generate a changelog section header
fun! s:GenHeader(path)
  let header =''

  if a:path == '\.'
    let header= "\nChangeLog:\n\n"
  else
    let header= "\n" . a:path . "/ChangeLog:\n\n"
  endif

  let header= header . s:date . '  '
  let header= header . g:CLauthor . '  '
  let header= header . '<' . g:CLemail . ">\n\n"

  return header
endfun

fun! s:ScanPatch(root)
  if !(exists("g:CLauthor"))
    let g:CLauthor="YOUR NAME"
  endif
  if !(exists("g:CLemail"))
    let g:CLemail="YOUR EMAIL"
  endif

  let s:date=strftime("%Y-%m-%d")

  let fileList=[]
  let funcList=[]
  let tempList=[]
  let newFileList=[]

  if !s:ScanPath(a:root)
    return
  endif

  let i = 1
  while i <= line('$')
    let line = getline(i)
    let i=i+1

    " scan the file field
    let fileName = ""
    let fileName1 = matchstr(line, '^---\s\(a\/\)\{,1}\zs\S\+\ze.*$')
    if fileName1 != ""
      let line = getline(i)
      let i=i+1
      let fileName2 = matchstr(line, '^+++\s\(b\/\)\{,1}\zs\S\+\ze.*$')
      if fileName1 == fileName2
	let fileName = fileName1
      else
	let fileName = (fileName1 == "/dev/null")? fileName2 : fileName1
      endif

      if (fileName1 == "/dev/null")
        call add (newFileList, fileName)
      endif
    endif

    if fileName != ""
      if len(tempList) != 0
	call add(funcList, tempList)
	let tempList=[]
      endif
      call add(fileList, fileName)
      continue
    endif

    let funcName = ""
    let found = matchstr(line, '^@@.\+@@')
    if found != ""
      let funcName = matchstr(line, '^@@.\+@@\s\zs.\+\ze\s(.\+$')
      if funcName == ""
	let funcName = matchstr(line, '^@@.\+@@\s\zs.\+\ze$')
	if funcName == ""
	  let funcName = " "
	endif
      endif
    endif
    if funcName != ""
      " Check if function already in the list
      let exist=0
      for element in tempList
	if element == funcName
	  let exist=1
	  break
	endif
      endfor
      if exist == 0
	call add(tempList, funcName)
      endif
    endif
  endwhile

  call add(funcList, tempList)

  if len(fileList) == 0
    echoh ErrorMsg | echo "OOps, nothing can be generated,
	  \ is this a real patch file?" | echoh None
    return
  endif

  let dict = {}
  for fileName in fileList
    let changeLog = s:FindCL(fileName)
    if empty (changeLog)
      return
    endif

    if has_key(dict, changeLog)
      call add (dict[changeLog], fileName)
    else
      let dict[changeLog] = [fileName]
    endif
  endfor

  let ChangeLog = ''
  for [key, val] in items(dict)
    let header = s:GenHeader(key)
    let body = ''

    for item in val
      let i = index (fileList, item)
      if key != '\.'
	let item = substitute (item, key, "", "")
      endif
      let item = substitute (item, "^/", "", "")
      if item == 'ChangeLog'
	continue
      endif

      if index (newFileList, fileList[i]) >= 0
	let body = body . "\t* " . item . ": New.\n"
      else
	let body = body . "\t* " . item . " (" . funcList[i][0] . "): \n"
      endif
      for funcName in funcList[i][1:]
	let body = body . "\t(" . funcName . "): \n"
      endfor

    endfor
    let ChangeLog = ChangeLog . header . body
  endfor

  let bufName="ChangeLog--reserved"

  let bufExists=0
  for b in range(1, bufnr('$'))
    if bufName == bufname(b)
      let bufExists=1
      break
    endif
  endfor
  if bufExists
    execute "bd ".bufName
  endif

  vnew
  execute "setl noai nocin nosi inde="
  execute 'set bt=nofile'
  execute 'f '. bufName
  call s:Refresh_minibufexpl_if()

  execute "normal! Go".ChangeLog
  call setpos('.',[0,1,1])
  execute 'set filetype=changelog'
  execute 'setlocal spell spelllang=en_us'

  " call getchar()
endfun

fun! s:Refresh_minibufexpl_if()
  if exists('g:loaded_minibufexplorer')
    execute "MBEToggle"
    execute "MBEToggle"
  endif
endfun

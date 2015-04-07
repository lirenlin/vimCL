if !has('python')
  echo "Error: Required vim compiled with +python"
  finish
endif

command! -nargs=1 GenCL1 call s:GenCL(<f-args>)
command! -narg=0 GenGCC execute 'GenCL1 /work/oban-work/src/gcc'

function! s:GenCL(repo)
python << EOF

import fnmatch
import os
import vim

#repo path
repo = vim.eval("a:repo")
#special file attribute, new, delete, ChangeLog etc.
special = dict ()

def echoMsg (msg):
  vim.command("echoh ErrorMsg | echo '%s' | echoh None" % msg)

def createBuf(name, content):
  for b in vim.buffers:
    if os.path.basename (b.name) == name:
      vim.command('let result = confirm ("ChangeLog buffer already exists. Overwrite?","&y\n&n", "2")')
      if vim.eval('result') == '1':
        vim.command("bd %s"%name)
      else:
        return

  vim.command("vnew")
  vim.command("setl noai nocin nosi inde=")
  vim.command("set bt=nofile")
  vim.command("f %s" % name)

  vim.command("set filetype=changelog")
  vim.command("setlocal spell spelllang=en_us")

  buf = vim.current.buffer
  buf.append(content)

  vim.command("call setpos('.', [0,1,1])")

def findCL(file, CLpath):
  path = file.split(os.sep)
  path = path[0:-1] #remove file name
  path = [x for x in path if x != '' ] #remove empty elements

  max = 0
  right = ""

  for cl in CLpath:
    dirs = cl.split(os.sep)
    if len(dirs) > len(path):
      continue

    depth = 0
    for index in range(len(dirs)):
      if dirs[index] == path[index]:
	depth += 1
      else:
	break
    if depth > max:
      max = depth
      right = cl

  #file path relative to the ChangeLog path
  file = os.sep.join(file.split(os.sep)[max:])
  return right, file

def scanRepo(repo):
  if not os.path.exists (repo):
    echoMsg ("%s dosen't exists, please check!" % repo)
    return []

  CLpath = []
  for root, dirnames, filenames in os.walk(repo):
    for filename in fnmatch.filter(filenames, 'ChangeLog'):
      CLpath.append(os.path.relpath(root, repo))

  if len(CLpath) == 0:
    echoMsg ("No ChangeLog found")
    return []
  else:
    return CLpath

def scanDiff():
  import re

  pattern1 = re.compile(r'^---\sa\/(?P<name>.+)$')
  pattern2 = re.compile(r'^\+\+\+\sb\/(?P<name>.+)$')

  new = re.compile(r'^--- \/dev\/null$')
  delete = re.compile(r'^\+\+\+ \/dev\/null$')

  pattern3 = re.compile(r'^@@.+?@@\s(?P<name>.+)$')

  buf = vim.current.buffer
  fileDict = dict()
  fileName = ""
  for index in range(len(buf)):
    line = buf[index]
    matchObj = pattern1.match(line)
    if matchObj:
      fileName = matchObj.group('name')
      index += 1
      line = buf[index]
      matchObj = pattern2.match(line)
      if matchObj and fileName == matchObj.group ('name'):
	fileDict[fileName] = list()
	continue
      else:
        matchObj = delete.match(line)
        if matchObj:
          fileName = matchObj.group ('name')
  	  fileDict[fileName] = list()
          special[fileName] = 'Deleted'
  	  continue
        else:
          echoMsg ("Bad diff")
          echoMsg ("%d: " % (index -1, buf[index-1]))
          echoMsg ("%d: " % (index, buf[index]))
    else:
      matchObj = new.match(line)
      if matchObj:
        index += 1
        line = buf[index]
        matchObj = pattern2.match(line)
        if matchObj:
          fileName = matchObj.group ('name')
  	  fileDict[fileName] = list()
          special[fileName] = 'New'
  	  continue
        else:
          echoMsg ("Bad diff")
          echoMsg ("%d: " % (index -1, buf[index-1]))
          echoMsg ("%d: " % (index, buf[index]))

    if fileName == "":
      continue

    if os.path.basename (fileName) == "ChangeLog":
      special[fileName] = 'ChangeLog'

    matchObj = pattern3.match(line)
    if matchObj:
      change = matchObj.group ('name')
      if fileName in fileDict:
	fileDict[fileName].append (change)
      else:
	fileDict[fileName] =  [change]

  return fileDict

def genCL(diff, CLpath):
  clDict = dict()
  for file in diff.keys():
    cl, file = findCL (file, CLpath)
    if not cl:
      echoMsg ("No ChangeLog file found for %s" % file)
    else:
      if cl in clDict:
	clDict[cl].append(file)
      else:
	clDict[cl] = [file]

  return clDict

def genHeader():
  import time
  date = time.strftime("%Y-%m-%d")
  string = "%s  %s  <%s>" % (date, "Renlin Li", "renlin.li@arm.com")
  return string

def genBody(clDict, fileDict):
  body = list()
  for key, value in clDict.iteritems():
    body.append("%s/ChangeLog:" % key)
    body.append('')
    body.append(genHeader ())
    for file in value:
      file = key + os.sep + file
      if file in special:
        if special[file] == 'Deleted':
	  body.append("\t* %s: Delete." % file)
	  continue
	elif special[file] == 'New':
	  body.append("\t* %s: New." % file)
	  continue
	elif special[file] == 'ChangeLog':
	  continue
      body.append("\t* %s (%s): " % (file, fileDict[file][0]))
      for change in fileDict[file][1:]:
	body.append("\t(%s): " % change)

    body.append('')

  return body

# Generate CL list
CLpath = scanRepo (repo)
if CLpath:
  # Generate change list
  fileDict = scanDiff ()
  if len(fileDict):
    clDict = genCL (fileDict, CLpath)

    # Generate ChangeLog content
    body = genBody (clDict, fileDict)

    createBuf ("ChangeLog-preserved", body)
  else:
    echoMsg ("No diff found in the file, is this really a diff file?")

EOF
endfunction

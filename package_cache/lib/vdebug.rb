STDOUT.sync = true

def pdebug(*args)
  file,line,method = caller[0].split(':')
  file = File.basename(file)
  print 'D>>',file,':',line,':',method,' :  ',*args,"\n"
end

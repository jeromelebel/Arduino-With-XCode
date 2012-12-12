#!/usr/local/bin/ruby

require 'fileutils'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

#puts ARGV.inspect
#puts ENV.inspect
#puts ENV.keys.inspect

@file_timestamp = {}
@verbose = false

def execute(parameters)
    if @verbose
        puts parameters.join(" ")
    end
    system *parameters
end

def load_hardware_info(info_filename, board_name)
    result = {}
    File.open(info_filename, "r") do |infile|
        while (line = infile.gets)
            line.strip!
            if !line.start_with?("#") && line != "" && line.start_with?(board_name + ".")
                equal_index = line.index("=")
                result[line[(board_name + ".").length..(equal_index - 1)].strip] = line[(equal_index + 1)..-1].strip
            end
        end
    end
    result
end

def file_timestamp(file)
    file = File.expand_path(file)
    if @file_timestamp[file].nil?
        @file_timestamp[file] = File.mtime(file)
    end
    @file_timestamp[file]
end

def should_build(source_filename, object_filename, dependency_filename)
    result = !File.exists?(object_filename)
    object_timestamp = nil
    if !result
        object_timestamp = File.ctime(object_filename)
        if File.directory?(object_filename)
            FileUtils.rm_r(object_filename)
        end
        result = object_timestamp < file_timestamp(source_filename) || !File.exists?(dependency_filename)
    end
    if !result
        File.open(dependency_filename, 'r') { |f|
            while line = f.gets
                line.strip!
                result = object_timestamp < file_timestamp(line)
                if result
                    break
                end
            end
        }
    end
    result
end

def build_directory(source_dir, build_dir, compilers, object_files, recursive)
    compiled = true
    if !File.directory?(build_dir)
        Dir.mkdir(build_dir)
    end
    Dir.foreach(source_dir) { |element|
        next if element == "." || element == ".."
        if File.directory?(source_dir + "/" + element)
            if recursive
                compiled &&= build_directory(source_dir + "/" + element, build_dir, compilers, object_files, recursive) || compiled
            end
            else
            object_filename = nil
            compiler = nil
            case File.extname(element)
                when ".cpp"
                object_filename = File.basename(element) + ".o"
                dependency_filename = File.basename(element, ".cpp") + ".dependency-header"
                if should_build(source_dir + "/" + element, build_dir + "/" + object_filename, build_dir + "/" + dependency_filename)
                    compiler = [ compilers[".cpp"][:command], source_dir + "/" + element, "-o", build_dir + "/" + object_filename, "-c", *compilers[".cpp"][:parameters] ]
                    dependency = [ compilers[".cpp"][:command], source_dir + "/" + element, "-o", build_dir + "/" + dependency_filename, "-E", *compilers[".cpp"][:parameters] ]
                end
                when ".c"
                object_filename = File.basename(element) + ".o"
                dependency_filename = File.basename(element, ".c") + ".dependency-header"
                if should_build(source_dir + "/" + element, build_dir + "/" + object_filename, build_dir + "/" + dependency_filename)
                    compiler = [ compilers[".c"][:command], source_dir + "/" + element, "-o", build_dir + "/" + object_filename, "-c", *compilers[".c"][:parameters] ]
                    dependency = [ compilers[".c"][:command], source_dir + "/" + element, "-o", build_dir + "/" + dependency_filename, "-E", *compilers[".c"][:parameters] ]
                end
            end
            if !object_filename.nil?
                object_files << build_dir + "/" + object_filename
                if !compiler.nil?
                    puts "  + " + File.basename(element)
                    compiled &&= execute(compiler)
                    system(*dependency)
                    header_hash = {}
                    File.open(build_dir + "/" + dependency_filename, 'r') { |f|
                        while line = f.gets
                            line.strip!
                            if line =~ /^# *[0-9]* "(.*)" *[0-9]*$/
                                if $1 != "<command-line>" && $1 != "<built-in>"
                                    header_hash[File.expand_path($1)] = true
                                end
                            end
                        end
                    }
                    File.open(build_dir + "/" + dependency_filename, 'w') { |f|
                        header_hash.each { |filename, notused|
                            f.puts(filename)
                        }
                    }
                end
            end
        end
        if !compiled
            break
        end
    }
    return compiled
end

def build(build_dir, sources, compilers)
    project_object_files = []
    begin
        File.open(build_dir + "/compiler_options", 'r') { |f|
            if f.read() != compilers.inspect
                clean(build_dir)
            end
        }
        rescue
        clean(build_dir)
    end
    if File.exists?(build_dir) && !File.directory?(build_dir)
        File.unlink(build_dir)
    end
    if !File.directory?(build_dir)
        Dir.mkdir(build_dir)
    end
    archive_files = []
    success = true
    sources.each { |source|
        source[:object_files] = []
        
        puts "building " + source[:source_dir]
        success &&= build_directory(source[:source_dir], source[:build_dir], compilers, source[:object_files], source[:recursive])
        if success || !File.exists?(source[:archive_file])
            if File.exists?(source[:archive_file])
                File.unlink(source[:archive_file])
            end
            source[:object_files].each { |object_file|
                parameters = [ compilers["archiver"][:command] ]
                parameters.push(*compilers["archiver"][:parameters])
                parameters << source[:archive_file]
                parameters << object_file
                success &&= execute(parameters)
            } if source[:name] != "project"
        end
        if source[:name] == "project"
            project_object_files = source[:object_files]
            else
            archive_files << source[:archive_file]
        end
        if !success
            break
        end
    }
    if success
        puts "Creating " + compilers["linker"][:parameters][compilers["linker"][:parameters].count - 1]
        parameters = [ compilers["linker"][:command] ]
        parameters.push(*compilers["linker"][:parameters])
        parameters.push(*project_object_files)
        parameters.push(*archive_files)
        success &&= execute(parameters)
    end
    
    if success
        puts "Creating " + compilers["objcopy"][:parameters][compilers["objcopy"][:parameters].count - 1]
        parameters = [ compilers["objcopy"][:command] ]
        parameters.push(*compilers["objcopy"][:parameters])
        success &&= execute(parameters)
    end
    
    File.open(build_dir + "/compiler_options", 'w') {|f| f.write(compilers.inspect) }
    return success
end

def clean(build_dir)
    if File.exists?(build_dir)
        FileUtils.rm_r(build_dir)
    end
end

def add_header_path(compiler, source_dir, recursive)
    compiler[:parameters] << "-I" + source_dir
    if recursive
        Dir.foreach(source_dir) { |element|
            next if element == "." || element == ".." || !File.directory?(source_dir + "/" + element)
            add_header_path(compiler, source_dir + "/" + element, recursive)
        }
    end
end

environment = { "optimisation" => "-Os",
    "hardware_path" => ENV['HARDWARE_PATH'],
    "board_name" => ENV['BOARD_NAME'],
    "avr_path" => ENV['AVR_BIN_PATH'],
    "arduino_version" => ENV['ARDUINO_VERSION'],
    "source_dir" => ENV['SOURCE_DIR'],
    "build_path" => ENV['BUILD_DIR'],
    "project_name" => ENV['PRODUCT_NAME'] }
if !ENV['HARDWARE_LIBRARIES'].nil? && ENV['HARDWARE_LIBRARIES'].length > 0
    environment["libraries"] = ENV['HARDWARE_LIBRARIES'].split(",")
    else
    environment["libraries"] = []
end
environment["library_path"] = ENV['HARDWARE_LIBRARY_DIR']

op = OptionParser.new do |opts|
    opts.on("--hardware-path <path>", String, "set the hardware path") { |path|
        environment["hardware_path"] = path
    }
    opts.on("-b", "--board-name <name>", String, "set the board name") { |name|
        environment["board_name"] = name
    }
    opts.on("-a", "--avr-path <path>", String, "set the avr path") { |path|
        environment["avr_path"] = path
    }
    opts.on("-v", "--arduino-version <version>", String, "set the arduino version") { |version|
        environment["arduino_version"] = version
    }
    opts.on("--build-path <path>", String, "set the build directory") { |path|
        environment["build_path"] = path
    }
    opts.on("-p", "--product-name <name>", String, "set the build directory") { |name|
        environment["project_name"] = name
    }
    opts.on("-l", "--libraries a,b,c", Array, "enabled libraries") { | library_array|
        environment["libraries"] = library_array
    }
    opts.on("--library-path <path>", String, "set the library directory") { |path|
        environment["library_path"] = path
    }
    opts.on("--optimisation [0, 1, 2, 3, s]", String, "set the compiler optimisation") { |string|
        environment["optimisation"] = "-O" + string
    }
    opts.on("--verbose", "set the library directory") {
        @verbose = true
    }
end

op.parse!(ARGV)

if ARGV.length > 0
    environment["source_dir"] = ARGV[0]
end

if environment["project_name"].nil? || environment["project_name"].length == 0 then
    environment["project_name"] = File.basename(File.expand_path(environment["source_dir"]))
end

if environment["avr_path"].nil?
    environment["avr_path"] = ""
end
if environment["avr_path"].length > 0 && environment["avr_path"][-1, 1] != "/" then
    environment["avr_path"] = environment["avr_path"] + "/"
end
environment["hardware_info"] = load_hardware_info(environment["hardware_path"] + "/boards.txt", environment["board_name"])
environment["hardware_variant_path"] = environment["hardware_path"] + "/variants/" + environment["hardware_info"]["build.variant"]
environment["hardware_core_path"] = environment["hardware_path"] + "/cores/" + environment["hardware_info"]["build.core"]

if environment["build_path"].nil? || environment["build_path"].length == 0 then
    environment["build_path"] = environment["source_dir"] + "/" + "build"
    else
    environment["build_path"] = environment["build_path"] + "/" + environment["project_name"]
end

compilers = {}
compilers[".c"] = {
    :command => environment["avr_path"] + "avr-gcc",
    :parameters => [
    "-c",
    "-g",
    environment["optimisation"],
    "-w",
    "-ffunction-sections",
    "-fdata-sections",
    "-mmcu=" + environment["hardware_info"]["build.mcu"],
    "-DF_CPU=" + environment["hardware_info"]["build.f_cpu"],
    "-MMD",
    "-DUSB_PID=null",
    "-DARDUINO=" + environment["arduino_version"],
    "-I" + environment["hardware_variant_path"],
    "-I" + environment["hardware_core_path"] ] }
compilers[".cpp"] = {
    :command => environment["avr_path"] + "avr-g++",
    :parameters => [
    "-c",
    "-g",
    environment["optimisation"],
    "-w",
    "-fno-exceptions",
    "-ffunction-sections",
    "-fdata-sections",
    "-mmcu=" + environment["hardware_info"]["build.mcu"],
    "-DF_CPU=" + environment["hardware_info"]["build.f_cpu"],
    "-MMD",
    "-DUSB_VID=null",
    "-DUSB_PID=null",
    "-DARDUINO=" + environment["arduino_version"],
    "-DSPEEDRATE=" + environment["hardware_info"]["upload.speed"],
    "-I" + environment["hardware_variant_path"],
    "-I" + environment["hardware_core_path"]  ] }
compilers["archiver"] = { :command => environment["avr_path"] + "avr-ar", :parameters => [ "rcs" ] }
compilers["linker"] = {
    :command => environment["avr_path"] + "avr-gcc",
    :parameters => [
    environment["optimisation"],
    "-Wl,--gc-sections,--relax",
    "-mmcu=" + environment["hardware_info"]["build.mcu"],
    "-lm",
    "-o",
    environment["build_path"] + "/" + environment["project_name"] + ".elf" ] }
compilers["objcopy"] = { :command => environment["avr_path"] + "avr-objcopy", :parameters => [ "-O", "ihex", "-R", ".eeprom", environment["build_path"] + "/" + environment["project_name"] + ".elf", environment["build_path"] + "/" + environment["project_name"] + ".hex" ] }

sources = [
{ :source_dir => environment["source_dir"], :build_dir => environment["build_path"] + "/project", :archive_file => environment["build_path"] + "/project/project.a", :name => "project", :recursive => true },
{ :source_dir => environment["hardware_core_path"], :build_dir => environment["build_path"] + "/core", :archive_file => environment["build_path"] + "/core/core.a", :name => "core", :recursive => false }
]
environment["libraries"].each { |library|
    library_name = library.split("/").join("_")
    sources << { :source_dir => environment["library_path"] + "/" + library, :build_dir => environment["build_path"] + "/lib_" + library_name, :archive_file => environment["build_path"] + "/lib_" + library_name + "/lib_" + library_name + ".a", :name => "lib_" + library, :recursive => false }
}

sources.each { |source|
    add_header_path(compilers[".c"], source[:source_dir], source[:recursive])
    add_header_path(compilers[".cpp"], source[:source_dir], source[:recursive])
}

if ARGV.count > 0 && ARGV[0] == "clean"
    success = clean(environment["build_path"])
    else
    success = build(environment["build_path"], sources, compilers)
end
if success
    exit(0)
    else
    exit(1)
end

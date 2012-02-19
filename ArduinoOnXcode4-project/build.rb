#!/usr/bin/ruby

#  build.rb
#  ArduinoOnXcode
#
#  Created by Jérôme Lebel on 16/02/12.
#  Copyright (c) 2012 Fotonauts. All rights reserved.

require 'FileUtils'

#puts ARGV.inspect
#puts ENV.inspect
#puts ENV.keys.inspect

def execute(parameters)
    puts parameters.join(" ")
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

def should_build(source_filename, object_filename)
    if File.directory?(object_filename)
        FileUtils.rm_r(object_filename)
    end
    return !File.exists?(object_filename) || File.ctime(object_filename) < File.mtime(source_filename)
end

def build_directory(source_dir, build_dir, compilers, object_files)
    compiled = false
    if !File.directory?(build_dir)
        Dir.mkdir(build_dir)
    end
    Dir.foreach(source_dir) { |element|
        next if element == "." || element == ".."
        if File.directory?(source_dir + "/" + element)
            compiled ||= build_directory(source_dir + "/" + element, build_dir, compilers, object_files)
        else
            object_filename = nil
            compiler = nil
            case File.extname(element)
                when ".cpp"
                    object_filename = File.basename(element, ".cpp") + ".o"
                    if should_build(source_dir + "/" + element, build_dir + "/" + object_filename)
                        compiler = [ compilers[".cpp"][:command], source_dir + "/" + element, "-o", build_dir + "/" + object_filename, *compilers[".cpp"][:parameters] ]
                    end
                when ".c"
                    object_filename = File.basename(element, ".c") + ".o"
                    if should_build(source_dir + "/" + element, build_dir + "/" + object_filename)
                        compiler = [ compilers[".c"][:command], source_dir + "/" + element, "-o", build_dir + "/" + object_filename, *compilers[".c"][:parameters] ]
                    end
            end
            if !object_filename.nil?
                object_files << build_dir + "/" + object_filename
                if !compiler.nil?
                    compiled = true
                    execute(compiler)
                end
            end
        end
    }
    return compiled
end

def build(build_dir, sources, compilers)
    project_object_files = []
    begin
        File.open(ENV['BUILD_DIR'] + "/compiler_options", 'r') { |f|
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
    sources.each { |source|
        source[:object_files] = []
        compiled = build_directory(source[:source_dir], source[:build_dir], compilers, source[:object_files])
        if compiled || !File.exists?(source[:archive_file])
            if File.exists?(source[:archive_file])
                File.unlink(source[:archive_file])
            end
            source[:object_files].each { |object_file|
                parameters = [ compilers["archiver"][:command] ]
                parameters.push(*compilers["archiver"][:parameters])
                parameters << source[:archive_file]
                parameters << object_file
                execute(parameters)
            } if source[:name] != "project"
        end
        if source[:name] == "project"
            project_object_files = source[:object_files]
        else
            archive_files << source[:archive_file]
        end
    }
    parameters = [ compilers["linker"][:command] ]
    parameters.push(*compilers["linker"][:parameters])
    parameters.push(*archive_files)
    parameters.push(*project_object_files)
    execute(parameters)
    
    parameters = [ compilers["objcopy"][:command] ]
    parameters.push(*compilers["objcopy"][:parameters])
    execute(parameters)
    
    File.open(ENV['BUILD_DIR'] + "/compiler_options", 'w') {|f| f.write(compilers.inspect) }
end

def clean(build_dir)
    if File.exists?(build_dir)
        FileUtils.rm_r(build_dir)
    end
end

hardware_info = load_hardware_info(ENV['BOARDS_TXT_PATH'], ENV['BOARD_NAME'])
avr_dir = ENV['ARDUINO_APP_PATH'] + "/Contents/Resources/Java/hardware/tools/avr/bin"
avr_dude_file = ENV['ARDUINO_APP_PATH'] + "/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf"
hardware_variant_path = ENV['HARDWARE_PATH'] + "/variants/" + hardware_info["build.variant"]
hardware_core_path = ENV['HARDWARE_PATH'] + "/cores/" + hardware_info["build.core"]

compilers = {}
compilers[".c"] = { :command => avr_dir + "/avr-gcc", :parameters => [ "-c", "-mmcu=" + hardware_info["build.mcu"], "-DF_CPU=" + hardware_info["build.f_cpu"], "-DARDUINO=100", "-DSPEEDRATE=" + hardware_info["upload.speed"], "-Os", "-funsigned-char", "-funsigned-bitfields", "-fpack-struct", "-fshort-enums", "-ffunction-sections", "-fdata-sections", "-Wl,-gc-sections", "-gstabs", "-Wall", "-Wstrict-prototypes", "-std=gnu99", "-I" + hardware_variant_path, "-I" + hardware_core_path ] }
compilers[".cpp"] = { :command => avr_dir + "/avr-gcc", :parameters => [ "-c", "-mmcu=" + hardware_info["build.mcu"], "-DF_CPU=" + hardware_info["build.f_cpu"], "-DARDUINO=100", "-DSPEEDRATE=" + hardware_info["upload.speed"], "-Os", "-funsigned-char", "-funsigned-bitfields", "-fpack-struct", "-fshort-enums", "-ffunction-sections", "-fdata-sections", "-Wl,-gc-sections", "-I" + hardware_variant_path, "-I" + hardware_core_path  ] }
compilers["archiver"] = { :command => avr_dir + "/avr-ar", :parameters => [ "rcs" ] }
compilers["linker"] = { :command => avr_dir + "/avr-gcc", :parameters => [ "-mmcu=" + hardware_info["build.mcu"], "-DF_CPU=" + hardware_info["build.f_cpu"], "-DARDUINO=100", "-DSPEEDRATE=" + hardware_info["upload.speed"], "-Os", "-funsigned-char", "-funsigned-bitfields", "-fpack-struct", "-fshort-enums", "-ffunction-sections", "-fdata-sections", "-Wl,-gc-sections", "-gstabs", "-Wall", "-Wstrict-prototypes", "-std=gnu99", "-lm", "-o", ENV['BUILD_DIR'] + "/" + ENV['PRODUCT_NAME'] + ".elf" ] }
compilers["objcopy"] = { :command => avr_dir + "/avr-objcopy", :parameters => [ "-O", "ihex", "-R", ".eeprom", ENV['BUILD_DIR'] + "/" + ENV['PRODUCT_NAME'] + ".elf", ENV['BUILD_DIR'] + "/" + ENV['PRODUCT_NAME'] + ".hex" ] }

sources = [ { :source_dir => ENV['PROJECT_DIR'], :build_dir => ENV['BUILD_DIR'] + "/project", :archive_file => ENV['BUILD_DIR'] + "/project/project.a", :name => "project" }, { :source_dir => hardware_core_path, :build_dir => ENV['BUILD_DIR'] + "/core", :archive_file => ENV['BUILD_DIR'] + "/core/core.a", :name => "core" } ]
ENV['HARDWARE_LIBRARIES'].split(" ").each { |library|
    library_name = library.split("/").join("_")
    sources << { :source_dir => ENV['HARDWARE_LIBRARY_DIR'] + "/" + library, :build_dir => ENV['BUILD_DIR'] + "/lib_" + library_name, :archive_file => ENV['BUILD_DIR'] + "/lib_" + library_name + "/lib_" + library_name + ".a", :name => "lib_" + library }
    compilers[".c"][:parameters] << "-I" + ENV['HARDWARE_LIBRARY_DIR'] + "/" + library
    compilers[".cpp"][:parameters] << "-I" + ENV['HARDWARE_LIBRARY_DIR'] + "/" + library
}

if ARGV.count > 0 && ARGV[0] == "clean"
    clean(ENV['BUILD_DIR'])
else
    build(ENV['BUILD_DIR'], sources, compilers)
end

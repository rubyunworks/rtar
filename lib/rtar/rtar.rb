module ProUtils
  require 'zlib'
  require 'tmpdir'
  require 'fileutils'

  require 'proutils/string'
  require 'proutils/nilclass'
  require 'proutils/minitar'

  class Rtar

    def initialize()
    end

    ### Pack rock archive.
    def pack(folder)
      basename = File.basename(folder)
      return unless write_okay?(basename + ".rock")
      temp_folder = tmpdir()
      temp_locale = File.join(temp_folder,basename)
      #FileUtils.rm_r( temp_locale ) if File.exist?( temp_locale )
      FileUtils.cp_r(folder,temp_folder)
      file = nil
      Dir.chdir(temp_folder) do
        file = pack_rec(basename)
      end
      raise "unexpect compression error" unless file
      FileUtils.cp(File.join(temp_folder, file), "./#{basename}.rock")
    end

    ### Recursive packing.
    def pack_rec(folder)
      puts "<< #{folder}" if $VERBOSE
      Dir.chdir(folder) do
        files = Dir.entries('.') - ['.', '..']
        files.each do |f|
          if File.directory?(f)
            pack_rec(f)
          else
            gzip(f)
          end
        end
      end
      seal(folder) #gzip(tar(folder),'.rock')
    end

    ### Unpack archive.
    def unpack(file)
      return unless gzip?(file)
      basename = File.basename(file)
      barename = basename.chomp('.rock')
      rock_ext = (basename != barename)
      rockname = barename + '.rock'
      unless rock_ext or $FORCE
        return nil.status(:no_rock_ext)
      end
      temp_folder = tmpdir()
      to_file = File.join(temp_folder, rockname)
      if rock_ext
        return unless write_okay?(barename)
        FileUtils.cp_r(file, to_file)
      elsif $FORCE
        FileUtils.mv(file, to_file)
      end
      Dir.chdir(temp_folder) do
        unpack_rec(rockname)
      end
      FileUtils.mv(File.join(temp_folder,barename), '.')
    end

    ### Recursive unpacking.
    def unpack_rec(file)
      puts ">> #{file}" if $VERBOSE
      folder = unseal(file) #untar(gunzip(file))
      Dir.chdir( folder ) do
        files = Dir.entries('.') - ['.','..']
        files.each do |f|
          if f =~ /\.rock$/
            unpack_rec(f)
          else
            gunzip(f)
          end
        end
      end
    end

    ### Extract a particular file from the archive.
    def extract(file)
      puts "NOT WORKING YET"
      return
      # TODO
    end

    ### List contents of an archive.
    def list(file)
      puts "NOT WORKING YET"
      return
      name = File.basename(file)
      temp_folder = Dir.tmpdir
      FileUtils.cp_r(file,temp_folder)
      Dir.chdir(temp_folder) do
        unpack_rec(name)
      end
      folder = name.chomp('.tar')
      Dir.glob(File.join(temp_folder,folder,'**/*'))
    end

  private

    ### Tar and gzip file.
    def seal(folder)
      puts "seal: #{folder}" if $VERBOSE

      to_file = folder + '.rtar'
      begin
        gzIO = Zlib::GzipWriter.new(File.open(to_file, 'wb'))
        tarIO = Archive::Tar::Minitar::Output.new(gzIO)
        Dir.chdir(folder) do
          files = Dir.entries('.') - ['.', '..']
          files.each do |file|
            #puts "#{folder}/#{file}" if $VERBOSE
            Archive::Tar::Minitar.pack_file(file, tarIO)
          end
        end
      ensure
        tarIO.close # automatically does gzIO.close
      end
      FileUtils.rm_r(folder)
      return to_file
    end

    ### Untar and gunzip file.
    def unseal(file)
      puts "unseal: #{file}" if $VERBOSE

      to_file = file.chomp('.rtar')
      tgz = Zlib::GzipReader.new(File.open(file, 'rb'))
      Archive::Tar::Minitar.unpack(tgz, to_file)
      FileUtils.rm(file)
      return to_file
    end

    ### Tar a folder.
    def tar(folder)
      puts "tar: #{folder}" if $VERBOSE

      begin
        fileIO = File.open("#{folder}.tar", 'wb')
        tarIO = Archive::Tar::Minitar::Output.new(fileIO)
        Dir.chdir(folder) do
          files = Dir.entries('.') - ['.', '..']
          files.each do |file|
            Archive::Tar::Minitar.pack_file(file, tarIO)
          end
        end
      ensure
        tarIO.close # automatically does fileIO.close
      end
      FileUtils.rm_r(folder)
      return "#{folder}.tar"
    end

    ### Untar a folder.
    def untar(file)
      puts "untar: #{file}" if $VERBOSE

      to_file = file.chomp('.tar')
      FileUtils.mkdir_p(to_file)
      #FileUtils.mv(file,unfile)
      #Dir.chdir(tofile) do
        Archive::Tar::Minitar.unpack(file,to_file)
        FileUtils.rm(file)
      #end
      return to_file
    end

    ### Compress file with gzip.
    def gzip(file)
      puts "gzip: #{file}" if $VERBOSE

      Zlib::GzipWriter.open("#{file}.gz") do |gz|
        gz.write File.read(file)
      end
      FileUtils.rm(file)
      return "#{file}.gz"
    end

    ### Uncompress a gzip file.
    def gunzip(file)
      puts "gunzip: #{file}" if $VERBOSE

      to_file = file.chomp('.gz')
      Zlib::GzipReader.open(file) do |gz|
        File.open(to_file,'wb') do |f|
          f << gz.read
        end
      end
      FileUtils.rm(file)
      return to_file
    end

    ### Is gzip file with message.
    def gzip?(file)
      unless File.gzip?(file)
        return nil.status(:not_rtar_archive)
      end
      return true
    end

    ### Is it okay to overwrite this file?
    def write_okay?(file)
      if File.exist?(file)
        if $FORCE
          FileUtils.rm_r(file)
        else
          return nil.status(:already_exists, file)
        end
      end
      true
    end

    ### Reserve a temproray file space.
    def tmpdir
      temp_folder = File.join(Dir.tmpdir,'rock')
      FileUtils.rm_r( temp_folder )
      FileUtils.mkdir_p( temp_folder )
      temp_folder
    end

    ### = Errors
    module Errors

      extend self

      def not_rtar_archive
        "file is not a rock archive"
      end

      def already_exists(file)
        "'#{file}' already exits. Use -f to overwrite"
      end

      def no_rtar_ext
        "no .rtar extension, either rename or use -f to replace"
      end

    end # module Errors

  end # class Rtar

end # class ProUtils


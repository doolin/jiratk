# frozen_string_literal: true

# Encapsulates the moving parts for cloning a file on Google Drive.
# TODO: move this after getting the DriveService figured out.
class TemplateCloner
  attr_reader :name, :url

  SERVICE_PREFIX = 'Covid'

  def initialize(id, fileservice, prefix = nil)
    @id = id
    @fs = fileservice
    @prefix = prefix || SERVICE_PREFIX
  end

  # Acquires the original template name, then adjusts the
  # name appropriately.
  # def name
  #   # https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/DriveV3/DriveService.html#get_file-instance_method
  #   file = @fs.get_file(@id)
  #   @name = adjust(file.name)
  # end

  # Makes a copy of the template and renames the copy,
  # passing back the url to the copy.
  # def url
  # end

  # TODO: check what gets returned from this function. I have
  # forgotten what Ruby will do in this case.
  def clone
    # https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/DriveV3/DriveService.html#get_file-instance_method
    file = @fs.get_file(@id)
    @name = adjust(file.name)

    new_file = @fs.copy_file(@id)
    copied_file = @fs.update_file(new_file.id, Google::Apis::DriveV3::File.new(name: name))
    @url = create_url(copied_file.id)
  end

  def adjust(name)
    name.gsub!(/Template/, '')
    "#{SERVICE_PREFIX} #{name} [test: delete me]"
  end

  def create_url(id)
    "https://docs.google.com/spreadsheets/d/#{id}/edit#gid=0"
  end
end

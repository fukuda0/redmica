#!/usr/bin/env ruby
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'net/http'
require 'net/https'
require 'uri'
require 'optparse'

module Net
  class HTTPS < HTTP
    def self.post_form(url, params, headers, options={})
      request = Post.new(url.path)
      request.form_data = params
      request.initialize_http_header(headers)
      request.basic_auth url.user, url.password if url.user
      http = new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      if options[:no_check_certificate]
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.start {|h| h.request(request) }
    end
  end
end

class RedmineMailHandler
  VERSION = '0.2.3'

  attr_accessor :verbose, :issue_attributes, :allow_override, :unknown_user, :default_group, :no_permission_check,
    :url, :key, :no_check_certificate, :no_account_notice, :no_notification

  def initialize
    self.issue_attributes = {}

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: rdm-mailhandler.rb [options] --url=<Redmine URL> --key=<API key>"
      opts.separator("")
      opts.separator("Reads an email from standard input and forwards it to a Redmine server through a HTTP request.")
      opts.separator("")
      opts.separator("Required arguments:")
      opts.on("-u", "--url URL",              "URL of the Redmine server") {|v| self.url = v}
      opts.on("-k", "--key KEY",              "Redmine API key") {|v| self.key = v}
      opts.separator("")
      opts.separator("General options:")
      opts.on("--no-permission-check",        "disable permission checking when receiving",
                                              "the email") {self.no_permission_check = '1'}
      opts.on("--key-file FILE",              "full path to a file that contains your Redmine",
                                              "API key (use this option instead of --key if",
                                              "you don't want the key to appear in the command",
                                              "line)") {|v| read_key_from_file(v)}
      opts.on("--no-check-certificate",       "do not check server certificate") {self.no_check_certificate = true}
      opts.on("-h", "--help",                 "show this help") {puts opts; exit 1}
      opts.on("-v", "--verbose",              "show extra information") {self.verbose = true}
      opts.on("-V", "--version",              "show version information and exit") {puts VERSION; exit}
      opts.separator("")
      opts.separator("User creation options:")
      opts.on("--unknown-user ACTION",        "how to handle emails from an unknown user",
                                              "ACTION can be one of the following values:",
                                              "* ignore: email is ignored (default)",
                                              "* accept: accept as anonymous user",
                                              "* create: create a user account") {|v| self.unknown_user = v}
      opts.on("--default-group GROUP",        "add created user to GROUP (none by default)",
                                              "GROUP can be a comma separated list of groups") { |v| self.default_group = v}
      opts.on("--no-account-notice",          "don't send account information to the newly",
                                              "created user") { |v| self.no_account_notice = '1'}
      opts.on("--no-notification",            "disable email notifications for the created",
                                              "user") { |v| self.no_notification = '1'}
      opts.separator("")
      opts.separator("Issue attributes control options:")
      opts.on("-p", "--project PROJECT",      "identifier of the target project") {|v| self.issue_attributes['project'] = v}
      opts.on("-s", "--status STATUS",        "name of the target status") {|v| self.issue_attributes['status'] = v}
      opts.on("-t", "--tracker TRACKER",      "name of the target tracker") {|v| self.issue_attributes['tracker'] = v}
      opts.on(      "--category CATEGORY",    "name of the target category") {|v| self.issue_attributes['category'] = v}
      opts.on(      "--priority PRIORITY",    "name of the target priority") {|v| self.issue_attributes['priority'] = v}
      opts.on(      "--private",              "create new issues as private") {|v| self.issue_attributes['is_private'] = '1'}
      opts.on("-o", "--allow-override ATTRS", "allow email content to override attributes",
                                              "specified by previous options",
                                              "ATTRS is a comma separated list of attributes") {|v| self.allow_override = v}
      opts.separator("")
      opts.separator("Examples:")
      opts.separator("No project specified, emails MUST contain the 'Project' keyword:")
      opts.separator("  rdm-mailhandler.rb --url http://redmine.domain.foo --key secret")
      opts.separator("")
      opts.separator("Fixed project and default tracker specified, but emails can override")
      opts.separator("both tracker and priority attributes using keywords:")
      opts.separator("  rdm-mailhandler.rb --url https://domain.foo/redmine --key secret \\")
      opts.separator("    --project foo \\")
      opts.separator("    --tracker bug \\")
      opts.separator("    --allow-override tracker,priority")

      opts.summary_width = 27
    end
    optparse.parse!

    unless url && key
      puts "Some arguments are missing. Use `rdm-mailhandler.rb --help` for getting help."
      exit 1
    end
  end

  def submit(email)
    uri = url.gsub(%r{/*$}, '') + '/mail_handler'

    headers = { 'User-Agent' => "Redmine mail handler/#{VERSION}" }

    data = { 'key' => key, 'email' => email,
                           'allow_override' => allow_override,
                           'unknown_user' => unknown_user,
                           'default_group' => default_group,
                           'no_account_notice' => no_account_notice,
                           'no_notification' => no_notification,
                           'no_permission_check' => no_permission_check}
    issue_attributes.each { |attr, value| data["issue[#{attr}]"] = value }

    debug "Posting to #{uri}..."
    begin
      response = Net::HTTPS.post_form(URI.parse(uri), data, headers, :no_check_certificate => no_check_certificate)
    rescue SystemCallError, IOError => e # connection refused, etc.
      warn "An error occured while contacting your Redmine server: #{e.message}"
      return 75 # temporary failure
    end
    debug "Response received: #{response.code}"

    case response.code.to_i
      when 403
        warn "Request was denied by your Redmine server. " +
             "Make sure that 'WS for incoming emails' is enabled in application settings and that you provided the correct API key."
        return 77
      when 422
        warn "Request was denied by your Redmine server. " +
             "Possible reasons: email is sent from an invalid email address or is missing some information."
        return 77
      when 400..499
        warn "Request was denied by your Redmine server (#{response.code})."
        return 77
      when 500..599
        warn "Failed to contact your Redmine server (#{response.code})."
        return 75
      when 201
        debug "Proccessed successfully"
        return 0
      else
        return 1
    end
  end

  private

  def debug(msg)
    puts msg if verbose
  end

  def read_key_from_file(filename)
    begin
      self.key = File.read(filename).strip
    rescue Exception => e
      $stderr.puts "Unable to read the key from #{filename}:\n#{e.message}"
      exit 1
    end
  end
end

handler = RedmineMailHandler.new
exit(handler.submit(STDIN.read))

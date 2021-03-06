require 'json'
require 'base64'

module Lita
  module Handlers
    class Jenkins < Handler
      class << self
        attr_accessor :jobs
      end

      def self.default_config(config)
        config.url = nil
        self.jobs = {}
      end

      route /j(?:enkins)? list( (.+))?/i, :jenkins_list, command: true, help: {
        'jenkins list <filter>' => 'lists Jenkins jobs'
      }

      route /j(?:enkins)? b(?:uild)? (\d+)/i, :jenkins_build, command: true, help: {
        'jenkins b(uild) <job_id>' => 'builds the job specified by job_id. List jobs to get ID.'
      }

      def jenkins_build(response)
        if job = jobs[response.matches.last.last.to_i - 1]
          url    = Lita.config.handlers.jenkins.url
          path   = "#{url}/job/#{job['name']}/build"

          http_resp = http.post(path) do |req|
            req.headers = headers
          end

          if http_resp.status == 201
            response.reply "(#{http_resp.status}) Build started for #{job['name']} #{url}/job/#{job['name']}"
          else
            response.reply http_resp.body
          end
        else
          response.reply "I couldn't find that job. Try `jenkins list` to get a list."
        end
      end

      def jenkins_list(response)
        filter = response.matches.first.last
        reply  = ''

        jobs.each_with_index do |job, i|
          job_name      = job['name']
          state         = color_to_state(job['color'])
          text_to_check = state + job_name

          reply << format_job(i, state, job_name) if filter_match(filter, text_to_check)
        end

        response.reply reply
      end

      def headers
        headers = {}
        if auth = Lita.config.handlers.jenkins.auth
          headers["Authorization"] = "Basic #{Base64.encode64(auth).chomp}"
        end
        headers
      end

      def jobs
        if self.class.jobs.empty?
          path = "#{Lita.config.handlers.jenkins.url}/api/json"
          api_response = http.get(path) do |req|
            req.headers = headers
          end
          self.class.jobs = JSON.parse(api_response.body)["jobs"]
        end
        self.class.jobs
      end

      private

      def format_job(i, state, job_name)
        "[#{i+1}] #{state} #{job_name}\n"
      end

      def color_to_state(text)
        case text
        when /disabled/
          'DISA'
        when /red/
          'FAIL'
        else
          'SUCC'
        end
      end

      def filter_match(filter, text)
        text.match(/#{filter}/i)
      end
    end

    Lita.register_handler(Jenkins)
  end
end

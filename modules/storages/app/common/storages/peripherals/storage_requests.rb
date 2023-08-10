#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
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
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Storages::Peripherals
  class StorageRequests
    def initialize(storage:)
      @storage = storage
    end

    # def self.call(storage:, operation:, **)
    #   Registry.resolve("queries.#{storage.short_provider_type}.#{operation}").call(storage:, **)
    # end

    private

    def method_missing(name, *args)
      resource_type = name.to_s.split('_').last.pluralize
      Registry.resolve("#{resource_type}.#{@storage.short_provider_type}.#{name}")
    rescue Dry::Container::KeyError
      super
    end

    def respond_to_missing?(name)
      resource_type = name.to_s.split('_').last.pluralize
      !!Registry.resolve("#{resource_type}.#{@storage.short_provider_type}.#{name}")
    rescue Dry::Container::KeyError
      super
    end
  end
end

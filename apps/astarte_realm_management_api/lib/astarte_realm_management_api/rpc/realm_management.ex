#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.RPC.RealmManagement do
  alias Astarte.RPC.Protocol.RealmManagement.{
    Call,
    DeleteInterface,
    DeleteTrigger,
    GenericErrorReply,
    GenericOkReply,
    GetInterfacesList,
    GetInterfacesListReply,
    GetInterfaceSource,
    GetInterfaceSourceReply,
    GetInterfaceVersionsList,
    GetInterfaceVersionsListReply,
    GetInterfaceVersionsListReplyVersionTuple,
    GetJWTPublicKeyPEM,
    GetJWTPublicKeyPEMReply,
    GetTrigger,
    GetTriggerReply,
    GetTriggersList,
    GetTriggersListReply,
    InstallInterface,
    InstallTrigger,
    Reply,
    UpdateInterface,
    UpdateJWTPublicKeyPEM
  }

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.API.Config

  require Logger

  @rpc_client Config.rpc_client()
  @destination Astarte.RPC.Protocol.RealmManagement.amqp_queue()

  def get_interface_versions_list(realm_name, interface_name) do
    %GetInterfaceVersionsList{
      realm_name: realm_name,
      interface_name: interface_name
    }
    |> encode_call(:get_interface_versions_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_interfaces_list(realm_name) do
    %GetInterfacesList{
      realm_name: realm_name
    }
    |> encode_call(:get_interfaces_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_interface(realm_name, interface_name, interface_major_version) do
    %GetInterfaceSource{
      realm_name: realm_name,
      interface_name: interface_name,
      interface_major_version: interface_major_version
    }
    |> encode_call(:get_interface_source)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def install_interface(realm_name, interface_json) do
    %InstallInterface{
      realm_name: realm_name,
      interface_json: interface_json,
      async_operation: true
    }
    |> encode_call(:install_interface)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def update_interface(realm_name, interface_json) do
    %UpdateInterface{
      realm_name: realm_name,
      interface_json: interface_json,
      async_operation: true
    }
    |> encode_call(:update_interface)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_interface(realm_name, interface_name, interface_major_version) do
    %DeleteInterface{
      realm_name: realm_name,
      interface_name: interface_name,
      interface_major_version: interface_major_version,
      async_operation: true
    }
    |> encode_call(:delete_interface)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_jwt_public_key_pem(realm_name) do
    %GetJWTPublicKeyPEM{
      realm_name: realm_name
    }
    |> encode_call(:get_jwt_public_key_pem)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    %UpdateJWTPublicKeyPEM{
      realm_name: realm_name,
      jwt_public_key_pem: jwt_public_key_pem
    }
    |> encode_call(:update_jwt_public_key_pem)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def install_trigger(realm_name, trigger_name, action, tagged_simple_triggers) do
    serialized_tagged_simple_triggers =
      Enum.map(tagged_simple_triggers, &TaggedSimpleTrigger.encode/1)

    %InstallTrigger{
      realm_name: realm_name,
      trigger_name: trigger_name,
      action: action,
      serialized_tagged_simple_triggers: serialized_tagged_simple_triggers
    }
    |> encode_call(:install_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_trigger(realm_name, trigger_name) do
    %GetTrigger{
      realm_name: realm_name,
      trigger_name: trigger_name
    }
    |> encode_call(:get_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_triggers_list(realm_name) do
    %GetTriggersList{
      realm_name: realm_name
    }
    |> encode_call(:get_triggers_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_trigger(realm_name, trigger_name) do
    %DeleteTrigger{
      realm_name: realm_name,
      trigger_name: trigger_name
    }
    |> encode_call(:delete_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  defp encode_call(call, callname) do
    %Call{call: {callname, call}}
    |> Call.encode()
  end

  defp decode_reply({:ok, encoded_reply}) when is_binary(encoded_reply) do
    %Reply{reply: reply} = Reply.decode(encoded_reply)
    reply
  end

  defp decode_reply({:error, reason}) do
    {:error, reason}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{async_operation: async}}) do
    if async do
      {:ok, :started}
    else
      :ok
    end
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: name}}) do
    try do
      reason = String.to_existing_atom(name)
      {:error, reason}
    rescue
      ArgumentError ->
        Logger.warn("Received unknown error: #{inspect(name)}")
        {:error, :unknown}
    end
  end

  defp extract_reply(
         {:get_interface_versions_list_reply, %GetInterfaceVersionsListReply{versions: versions}}
       ) do
    result =
      for version <- versions do
        %GetInterfaceVersionsListReplyVersionTuple{
          major_version: major_version,
          minor_version: minor_version
        } = version

        [major_version: major_version, minor_version: minor_version]
      end

    {:ok, result}
  end

  defp extract_reply(
         {:get_interfaces_list_reply, %GetInterfacesListReply{interfaces_names: list}}
       ) do
    {:ok, list}
  end

  defp extract_reply({:get_interface_source_reply, %GetInterfaceSourceReply{source: source}}) do
    {:ok, source}
  end

  defp extract_reply(
         {:get_jwt_public_key_pem_reply, %GetJWTPublicKeyPEMReply{jwt_public_key_pem: pem}}
       ) do
    {:ok, pem}
  end

  defp extract_reply(
         {:get_trigger_reply,
          %GetTriggerReply{
            trigger_data: trigger_data,
            serialized_tagged_simple_triggers: serialized_tagged_simple_triggers
          }}
       ) do
    %Trigger{
      name: trigger_name,
      action: trigger_action
    } = Trigger.decode(trigger_data)

    tagged_simple_triggers =
      for serialized_tagged_simple_trigger <- serialized_tagged_simple_triggers do
        TaggedSimpleTrigger.decode(serialized_tagged_simple_trigger)
      end

    {
      :ok,
      %{
        trigger_name: trigger_name,
        trigger_action: trigger_action,
        tagged_simple_triggers: tagged_simple_triggers
      }
    }
  end

  defp extract_reply({:get_triggers_list_reply, %GetTriggersListReply{triggers_names: triggers}}) do
    {:ok, triggers}
  end
end

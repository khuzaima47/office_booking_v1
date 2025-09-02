defmodule OfficeBooking.MessagingTest do
  use OfficeBooking.DataCase

  alias OfficeBooking.Messaging

  describe "messages" do
    alias OfficeBooking.Messaging.Message

    import OfficeBooking.MessagingFixtures

    @invalid_attrs %{subject: nil, content: nil, read_at: nil}

    test "list_messages/0 returns all messages" do
      message = message_fixture()
      assert Messaging.list_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Messaging.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = %{subject: "some subject", content: "some content", read_at: ~U[2025-08-31 06:44:00Z]}

      assert {:ok, %Message{} = message} = Messaging.create_message(valid_attrs)
      assert message.subject == "some subject"
      assert message.content == "some content"
      assert message.read_at == ~U[2025-08-31 06:44:00Z]
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messaging.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = message_fixture()
      update_attrs = %{subject: "some updated subject", content: "some updated content", read_at: ~U[2025-09-01 06:44:00Z]}

      assert {:ok, %Message{} = message} = Messaging.update_message(message, update_attrs)
      assert message.subject == "some updated subject"
      assert message.content == "some updated content"
      assert message.read_at == ~U[2025-09-01 06:44:00Z]
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Messaging.update_message(message, @invalid_attrs)
      assert message == Messaging.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Messaging.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Messaging.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Messaging.change_message(message)
    end
  end
end

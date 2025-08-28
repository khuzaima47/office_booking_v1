defmodule OfficeBooking.BookingsTest do
  use OfficeBooking.DataCase

  alias OfficeBooking.Bookings

  describe "bookings" do
    alias OfficeBooking.Bookings.Booking

    import OfficeBooking.BookingsFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil, start_datetime: nil, end_datetime: nil}

    test "list_bookings/0 returns all bookings" do
      booking = booking_fixture()
      assert Bookings.list_bookings() == [booking]
    end

    test "get_booking!/1 returns the booking with given id" do
      booking = booking_fixture()
      assert Bookings.get_booking!(booking.id) == booking
    end

    test "create_booking/1 with valid data creates a booking" do
      valid_attrs = %{status: "some status", description: "some description", title: "some title", start_datetime: ~U[2025-08-27 09:03:00Z], end_datetime: ~U[2025-08-27 09:03:00Z]}

      assert {:ok, %Booking{} = booking} = Bookings.create_booking(valid_attrs)
      assert booking.status == "some status"
      assert booking.description == "some description"
      assert booking.title == "some title"
      assert booking.start_datetime == ~U[2025-08-27 09:03:00Z]
      assert booking.end_datetime == ~U[2025-08-27 09:03:00Z]
    end

    test "create_booking/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Bookings.create_booking(@invalid_attrs)
    end

    test "update_booking/2 with valid data updates the booking" do
      booking = booking_fixture()
      update_attrs = %{status: "some updated status", description: "some updated description", title: "some updated title", start_datetime: ~U[2025-08-28 09:03:00Z], end_datetime: ~U[2025-08-28 09:03:00Z]}

      assert {:ok, %Booking{} = booking} = Bookings.update_booking(booking, update_attrs)
      assert booking.status == "some updated status"
      assert booking.description == "some updated description"
      assert booking.title == "some updated title"
      assert booking.start_datetime == ~U[2025-08-28 09:03:00Z]
      assert booking.end_datetime == ~U[2025-08-28 09:03:00Z]
    end

    test "update_booking/2 with invalid data returns error changeset" do
      booking = booking_fixture()
      assert {:error, %Ecto.Changeset{}} = Bookings.update_booking(booking, @invalid_attrs)
      assert booking == Bookings.get_booking!(booking.id)
    end

    test "delete_booking/1 deletes the booking" do
      booking = booking_fixture()
      assert {:ok, %Booking{}} = Bookings.delete_booking(booking)
      assert_raise Ecto.NoResultsError, fn -> Bookings.get_booking!(booking.id) end
    end

    test "change_booking/1 returns a booking changeset" do
      booking = booking_fixture()
      assert %Ecto.Changeset{} = Bookings.change_booking(booking)
    end
  end
end

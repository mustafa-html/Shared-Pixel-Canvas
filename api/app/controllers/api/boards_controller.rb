module Api
  class BoardsController < ApplicationController
    # The whole board as raw bytes, four bits per pixel. The sequence number
    # in the header tells the client which live updates are already included.
    def show
      bytes, seq = BoardStore.read

      if bytes.nil?
        RebuildBoardJob.perform_later
        return render_board_rebuilding
      end

      response.set_header("X-Board-Seq", seq.to_s)
      response.set_header("Cache-Control", "no-store")
      send_data bytes, type: "application/octet-stream", disposition: "inline"
    end
  end
end

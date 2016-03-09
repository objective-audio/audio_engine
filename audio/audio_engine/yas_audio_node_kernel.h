//
//  yas_audio_node_kernel.h
//

#pragma once

class yas::audio::node::kernel : public manageable_kernel {
   public:
    kernel();
    virtual ~kernel();

    audio::connection_smap input_connections() const;
    audio::connection_smap output_connections() const;
    audio::connection input_connection(UInt32 const bus_idx);
    audio::connection output_connection(UInt32 const bus_idx);

   private:
    class impl;
    std::unique_ptr<impl> _impl;

    kernel(kernel const &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(kernel const &) = delete;
    kernel &operator=(kernel &&) = delete;

    // from node

    void _set_input_connections(audio::connection_wmap const &) override;
    void _set_output_connections(audio::connection_wmap const &) override;

#if YAS_TEST
   public:
    class private_access;
    friend private_access;
#endif
};

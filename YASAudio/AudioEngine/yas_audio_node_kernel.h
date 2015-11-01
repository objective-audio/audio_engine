//
//  yas_audio_node_kernel.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

class yas::audio_node::kernel : public kernel_from_node
{
   public:
    kernel();
    virtual ~kernel();

    audio_connection_smap input_connections() const;
    audio_connection_smap output_connections() const;
    audio_connection input_connection(const UInt32 bus_idx);
    audio_connection output_connection(const UInt32 bus_idx);

   private:
    class impl;
    std::unique_ptr<impl> _impl;

    kernel(const kernel &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(const kernel &) = delete;
    kernel &operator=(kernel &&) = delete;

    // from node

    void _set_input_connections(const audio_connection_wmap &) override;
    void _set_output_connections(const audio_connection_wmap &) override;

   public:
    class private_access;
    friend private_access;
};
